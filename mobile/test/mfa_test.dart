// ¿PARA QUÉ SIRVE?
//   Prueba la verificación en dos pasos de la app (T8).
//
// ¿QUÉ HACE?
//   Revisa que el código pegado se limpie, que la cuenta regresiva se escriba
//   bien, que ninguna ruta interna se abra sin el código, y que el código
//   correcto entre mientras el incorrecto o los muchos intentos se rechacen.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias el flujo del acceso o los mensajes, ajusta esta prueba y corre
//   `flutter test`.

import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/navigation/routes.dart';
import 'package:tyckops/core/network/token_storage.dart';
import 'package:tyckops/data/models/user_role.dart';
import 'package:tyckops/data/repositories/auth_repository.dart';
import 'package:tyckops/features/auth/auth_session.dart';
import 'package:tyckops/features/auth/mfa/mfa_controller.dart';
import 'package:tyckops/features/auth/mfa/mfa_logic.dart';

/// Guarda el token en memoria (las pruebas no tienen almacenamiento seguro).
class _MemoryTokenStorage implements TokenStorage {
  String? _token;
  @override
  Future<void> saveToken(String token) async => _token = token;
  @override
  Future<String?> readToken() async => _token;
  @override
  Future<void> clear() async => _token = null;
}

void main() {
  group('Reglas del código', () {
    test('al pegar, se quedan solo los 6 números', () {
      expect(sanitizeCode('Tu código es 842 913'), '842913');
      expect(sanitizeCode('12-34-56-78'), '123456');
      expect(sanitizeCode('sin números'), '');
    });

    test('la cuenta regresiva se escribe como mm:ss y nunca es negativa', () {
      expect(formatCountdown(const Duration(minutes: 2, seconds: 5)), '02:05');
      expect(formatCountdown(const Duration(seconds: 59)), '00:59');
      expect(formatCountdown(const Duration(seconds: -3)), '00:00');
    });
  });

  group('Rutas con verificación pendiente', () {
    test('sin el código no se abre ninguna ruta interna', () {
      for (final ruta in [Routes.workerHome, Routes.workerTickets, Routes.adminHome, Routes.login]) {
        expect(
          redirectFor(loggedIn: false, role: null, location: ruta, mfaPending: true),
          Routes.mfaVerification,
        );
      }
      expect(redirectFor(loggedIn: false, role: null, location: Routes.mfaVerification, mfaPending: true), isNull);
    });

    test('sin verificación pendiente, esa pantalla lleva al login o al inicio', () {
      expect(redirectFor(loggedIn: false, role: null, location: Routes.mfaVerification), Routes.login);
      expect(
        redirectFor(loggedIn: true, role: UserRole.worker, location: Routes.mfaVerification),
        Routes.workerHome,
      );
    });
  });

  group('Flujo completo con el modo de prueba (código 123456)', () {
    Future<(AuthSession, FakeAuthRepository, MfaController)> preparar() async {
      final session = AuthSession(_MemoryTokenStorage());
      final repo = FakeAuthRepository();
      // Primera vez: primer acceso (sin código).
      final primero = await repo.login(email: 'colaborador@gamaitaly.cl', password: 'prueba1234');
      expect(primero.needsMfa, isFalse);
      await repo.completeFirstAccess(termsVersion: 'GA-TOS-2026');
      // Segunda vez: ahora pide el código.
      final segundo = await repo.login(email: 'colaborador@gamaitaly.cl', password: 'prueba1234');
      expect(segundo.needsMfa, isTrue);
      session.startMfa(segundo.mfa!);
      return (session, repo, MfaController(session: session, repository: repo));
    }

    test('código incorrecto se rechaza; el correcto entra a la app', () async {
      final (session, _, mfa) = await preparar();
      expect(session.mfaPending, isTrue);

      expect(await mfa.verify('000000'), isFalse);
      expect(mfa.error, contains('Código incorrecto'));
      expect(mfa.codeRejected, isTrue);
      expect(session.isLoggedIn, isFalse);

      expect(await mfa.verify('123456'), isTrue);
      expect(session.isLoggedIn, isTrue);
      expect(session.mfaPending, isFalse);
      mfa.dispose();
    });

    test('al 3.er código incorrecto caduca y vuelve al login con el aviso', () async {
      final (session, _, mfa) = await preparar();
      await mfa.verify('999999');
      await mfa.verify('999999');
      expect(mfa.error, contains('queda 1 intento'));
      expect(session.mfaPending, isTrue, reason: 'con 2 errores todavía puede intentar');
      await mfa.verify('999999');
      expect(session.mfaPending, isFalse, reason: 'se cancela la verificación');
      expect(session.isLoggedIn, isFalse);
      expect(session.takeNotice(), contains('Demasiados intentos'));
      mfa.dispose();
    });
  });
}
