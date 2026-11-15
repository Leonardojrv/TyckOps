// CAPA DE DATOS DE LA APP contra el backend real y PostgreSQL.
// Usa las mismas clases que la app en producción: ApiClient (Dio) y
// ApiAuthRepository. Comprueba que la app entiende cada respuesta y error.
//
// Ejecutar (desde mobile/, con Docker levantado):
//   flutter test test_integracion

@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/network/api_client.dart';
import 'package:tyckops/core/network/api_exception.dart';
import 'package:tyckops/data/models/user_role.dart';
import 'package:tyckops/data/repositories/auth_repository.dart';

import 'soporte/entorno.dart';

void main() {
  final backend = BackendDePrueba();
  late TokenEnMemoria tokens;
  late ApiAuthRepository repo;
  var sesionCerradaPorServidor = 0;

  setUpAll(prepararBase);

  // El backend limita el login a 5 intentos cada 15 minutos. Para que ese
  // límite no se arrastre entre pruebas, cada una usa un backend recién iniciado.
  tearDown(backend.detener);

  setUp(() async {
    await reiniciarDatos();
    await backend.iniciar();
    tokens = TokenEnMemoria();
    sesionCerradaPorServidor = 0;
    repo = ApiAuthRepository(ApiClient(
      tokenStorage: tokens,
      baseUrl: urlApi,
      onUnauthorized: () => sesionCerradaPorServidor++,
    ));
  });

  Future<void> entrar((String, String) cuenta) async {
    final r = await repo.login(email: cuenta.$1, password: cuenta.$2);
    await tokens.saveToken(r.token); // lo mismo que hace AuthSession.signIn
  }

  group('Login desde la app', () {
    test('colaborador: la app recibe y entiende su usuario', () async {
      final r = await repo.login(email: Cuentas.colaboradorActivo.$1, password: Cuentas.colaboradorActivo.$2);
      expect(r.token.split('.'), hasLength(3)); // JWT
      expect(r.user.role, UserRole.worker);
      expect(r.user.name, 'Martin');
      expect(r.user.area, 'Servicios generales');
      expect(r.user.isFirstLogin, isFalse);
      expect(r.user.termsAccepted, isTrue);
    });

    test('administrador: rol admin', () async {
      final r = await repo.login(email: Cuentas.adminActivo.$1, password: Cuentas.adminActivo.$2);
      expect(r.user.role, UserRole.admin);
      expect(r.user.area, 'Administracion');
    });

    test('la app normaliza el correo (mayúsculas y espacios)', () async {
      final r = await repo.login(email: '  COLABORADOR.ACTIVO@GAMAITALY.CL ', password: Cuentas.colaboradorActivo.$2);
      expect(r.user.email, Cuentas.colaboradorActivo.$1);
    });

    test('clave incorrecta: ApiException 401 con el mensaje del servidor', () async {
      await expectLater(
        repo.login(email: Cuentas.colaboradorActivo.$1, password: 'ClaveMala123'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.code, 'code', 'CREDENCIALES_INVALIDAS')
            .having((e) => e.message, 'message', 'Correo o contraseña incorrectos.')),
      );
      // Un 401 en el login también dispara el cierre de sesión local (sin efecto real).
      expect(sesionCerradaPorServidor, 1);
    });

    test('correo no corporativo: 400 DATOS_INVALIDOS', () async {
      await expectLater(
        repo.login(email: 'usuario@example.com', password: 'loquesea1'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.code, 'code', 'DATOS_INVALIDOS')),
      );
    });

    test('rol no habilitado: 403 ROL_INVALIDO', () async {
      await expectLater(
        repo.login(email: Cuentas.sinRolValido.$1, password: Cuentas.sinRolValido.$2),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.code, 'code', 'ROL_INVALIDO')),
      );
    });
  });

  group('Sesión (/auth/me)', () {
    test('con token: devuelve el mismo usuario del login', () async {
      await entrar(Cuentas.adminActivo);
      final yo = await repo.currentUser();
      expect(yo.email, Cuentas.adminActivo.$1);
      expect(yo.role, UserRole.admin);
    });

    test('sin token: 401 y la app cierra la sesión', () async {
      await expectLater(
        repo.currentUser(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.code, 'code', 'NO_AUTENTICADO')),
      );
      expect(sesionCerradaPorServidor, 1);
    });

    test('token falso: 401 TOKEN_INVALIDO, se borra el token guardado', () async {
      await tokens.saveToken('token.falso.123');
      await expectLater(
        repo.currentUser(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TOKEN_INVALIDO')),
      );
      expect(await tokens.readToken(), isNull);
    });
  });

  group('Primer acceso y Términos', () {
    test('usuario nuevo: la app recibe isFirstLogin=true y termsAccepted=false', () async {
      final r = await repo.login(email: Cuentas.colaboradorNuevo.$1, password: Cuentas.colaboradorNuevo.$2);
      expect(r.user.isFirstLogin, isTrue);
      expect(r.user.termsAccepted, isFalse);
    });

    test('aceptar Términos manteniendo la clave: se guarda en PostgreSQL', () async {
      await entrar(Cuentas.colaboradorNuevo);
      final u = await repo.completeFirstAccess(termsVersion: 'GA-TOS-2026');
      expect(u.isFirstLogin, isFalse);
      expect(u.termsAccepted, isTrue);

      final fila = await usuarioEnBd(Cuentas.colaboradorNuevo.$1);
      expect(fila['isFirstLogin'], isFalse);
      expect(fila['termsAccepted'], isTrue);
      expect(fila['termsVersion'], 'GA-TOS-2026');
      expect(fila['termsAcceptedAt'], isNotNull);
    });

    test('aceptar Términos cambiando la clave: la nueva sirve para entrar', () async {
      await entrar(Cuentas.adminNuevo);
      await repo.completeFirstAccess(
        termsVersion: 'GA-TOS-2026',
        currentPassword: Cuentas.adminNuevo.$2,
        newPassword: 'NuevaDesdeLaApp2026',
      );
      final r = await repo.login(email: Cuentas.adminNuevo.$1, password: 'NuevaDesdeLaApp2026');
      expect(r.user.isFirstLogin, isFalse);
    });

    test('versión de Términos distinta: 400 TERMINOS_REQUERIDOS y la BD no cambia', () async {
      await entrar(Cuentas.colaboradorNuevo);
      await expectLater(
        repo.completeFirstAccess(termsVersion: 'VERSION-VIEJA'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.code, 'code', 'TERMINOS_REQUERIDOS')),
      );
      final fila = await usuarioEnBd(Cuentas.colaboradorNuevo.$1);
      expect(fila['isFirstLogin'], isTrue);
      expect(fila['termsAccepted'], isFalse);
    });

    test('clave temporal incorrecta: 400 CONTRASENA_ACTUAL_INCORRECTA (la sesión sigue)', () async {
      await entrar(Cuentas.colaboradorNuevo);
      await expectLater(
        repo.completeFirstAccess(
          termsVersion: 'GA-TOS-2026',
          currentPassword: 'NoEsLaActual1',
          newPassword: 'OtraClave2026',
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CONTRASENA_ACTUAL_INCORRECTA')),
      );
      expect(sesionCerradaPorServidor, 0); // 400, no 401: no se expulsa al usuario
      expect(await tokens.readToken(), isNotNull);
    });

    test('repetir el primer acceso: 409 PRIMER_ACCESO_COMPLETADO', () async {
      await entrar(Cuentas.colaboradorActivo);
      await expectLater(
        repo.completeFirstAccess(termsVersion: 'GA-TOS-2026'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'PRIMER_ACCESO_COMPLETADO')),
      );
    });
  });

  group('Errores de red', () {
    test('backend apagado: mensaje claro de sin conexión', () async {
      final sinServidor = ApiAuthRepository(ApiClient(
        tokenStorage: TokenEnMemoria(),
        baseUrl: 'http://127.0.0.1:3999/api', // puerto sin servidor
      ));
      await expectLater(
        sinServidor.login(email: Cuentas.adminActivo.$1, password: Cuentas.adminActivo.$2),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          'No hay conexión con el servidor. Revisa tu internet.',
        )),
      );
    });
  });
}
