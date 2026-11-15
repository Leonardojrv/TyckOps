// PANTALLAS DE LA APP, de punta a punta: la app completa (TyckOpsApp, con
// su router real) usa la API real, que a su vez usa PostgreSQL.
// Se escribe en los campos y se tocan los botones como lo haría una persona.
//
// Ejecutar (desde mobile/, con Docker levantado):
//   flutter test test_integracion

@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tyckops/app.dart';
import 'package:tyckops/core/navigation/routes.dart';
import 'package:tyckops/core/network/api_client.dart';
import 'package:tyckops/data/repositories/auth_repository.dart';
import 'package:tyckops/data/repositories/ticket_repository.dart';
import 'package:tyckops/features/auth/auth_session.dart';
import 'package:tyckops/features/worker/my_tickets_store.dart';

import 'soporte/entorno.dart';

void main() {
  final backend = BackendDePrueba();

  setUpAll(() async {
    await prepararBase();
    // flutter_test dibuja el texto con una fuente de cuadrados (más ancha que
    // la real), lo que provoca desbordes falsos. Se carga Segoe UI de Windows,
    // de medidas parecidas a Inter, con los nombres que pide google_fonts.
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await cargarFuentesDelSistema();
  });

  setUp(() async {
    await reiniciarDatos();
    await backend.iniciar(); // backend nuevo: el límite de intentos parte en cero
  });

  tearDown(backend.detener);

  /// Arma la app igual que main.dart, pero apuntando al backend de prueba.
  Future<AuthSession> abrirApp(WidgetTester tester) async {
    HttpOverrides.global = null; // flutter_test bloquea HTTP real por defecto
    tester.view.physicalSize = const Size(1080, 2400); // teléfono 360 x 800
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final tokens = TokenEnMemoria();
    final session = AuthSession(tokens);
    final api = ApiClient(tokenStorage: tokens, baseUrl: urlApi, onUnauthorized: session.signOut);
    final ticketRepository = ApiTicketRepository(api);
    final ticketsStore = MyTicketsStore(ticketRepository, session);
    addTearDown(ticketsStore.dispose);
    await tester.pumpWidget(TyckOpsApp(
      session: session,
      apiClient: api,
      authRepository: ApiAuthRepository(api),
      ticketsStore: ticketsStore,
    ));
    await tester.pumpAndSettle();
    return session;
  }

  /// Deja correr la red de verdad hasta que aparezca [finder].
  Future<void> esperar(WidgetTester tester, Finder finder, {int segundos = 15}) async {
    for (var i = 0; i < segundos * 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 400)); // termina animaciones
        return;
      }
    }
    fail('No apareció: $finder');
  }

  Future<void> tocar(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> iniciarSesion(WidgetTester tester, (String, String) cuenta) async {
    expect(find.text('Portal Corporativo'), findsOneWidget, reason: 'debe partir en el login');
    await tester.enterText(find.byType(TextFormField).at(0), cuenta.$1);
    await tester.enterText(find.byType(TextFormField).at(1), cuenta.$2);
    await tocar(tester, find.text('Iniciar sesión'));
  }

  // Lo que distingue cada pantalla principal.
  final menuColaborador = [find.text('Reportar falla'), find.text('Mis solicitudes')];
  final menuAdmin = [find.text('Tickets'), find.text('Dashboard')];
  final pantallaPrimerAcceso = find.text('Guardar preferencias y continuar');
  const textoAceptar = 'He leído y acepto los términos y condiciones de uso de la plataforma interna.';

  void verPantallaColaborador() {
    for (final f in menuColaborador) {
      expect(f, findsOneWidget);
    }
    for (final f in menuAdmin) {
      expect(f, findsNothing, reason: 'el colaborador no debe ver el menú de administrador');
    }
  }

  void verPantallaAdmin() {
    for (final f in menuAdmin) {
      expect(f, findsOneWidget);
    }
    for (final f in menuColaborador) {
      expect(f, findsNothing, reason: 'el administrador no debe ver el menú del colaborador');
    }
  }

  /// testWidgets que, al terminar, cierra la app y deja vencer el temporizador
  /// de conexión inactiva de Dio (si no, flutter_test reclama un Timer pendiente).
  void probarApp(String nombre, Future<void> Function(WidgetTester) cuerpo) {
    testWidgets(nombre, (tester) async {
      await cuerpo(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });
  }

  GoRouter router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first));

  group('Login correcto', () {
    probarApp('colaborador activo entra directo a SU pantalla', (tester) async {
      final session = await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.colaboradorActivo);
      await esperar(tester, menuColaborador.first);

      verPantallaColaborador();
      expect(find.text('Inicio'), findsWidgets);
      expect(session.user!.name, 'Martin');
      expect(session.user!.area, 'Servicios generales');
    });

    probarApp('administrador activo entra directo a SU pantalla', (tester) async {
      final session = await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.adminActivo);
      await esperar(tester, menuAdmin.first);

      verPantallaAdmin();
      expect(session.user!.name, 'Pablo');
    });
  });

  group('Login incorrecto', () {
    probarApp('clave equivocada: aviso del servidor y sigue en el login', (tester) async {
      final session = await abrirApp(tester);
      await iniciarSesion(tester, (Cuentas.colaboradorActivo.$1, 'ClaveMala123'));
      await esperar(tester, find.text('Correo o contraseña incorrectos.'));

      expect(find.text('Portal Corporativo'), findsOneWidget);
      expect(session.isLoggedIn, isFalse);
      // Seguridad: el campo de contraseña se vacía tras el error.
      final clave = tester.widget<EditableText>(find.byType(EditableText).at(1));
      expect(clave.controller.text, isEmpty);
    });

    probarApp('correo no corporativo: la app lo bloquea antes de llamar al servidor', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, ('usuario@example.com', 'cualquiera1'));
      await tester.pump();
      expect(find.text('Usa tu correo corporativo (@gamaitaly.cl)'), findsOneWidget);
      expect(find.text('Portal Corporativo'), findsOneWidget);
    });

    probarApp('rol no habilitado: aviso 403 y no entra', (tester) async {
      final session = await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.sinRolValido);
      await esperar(tester, find.text('La cuenta no tiene un rol habilitado.'));
      expect(session.isLoggedIn, isFalse);
    });

    probarApp('6 intentos fallidos: aviso de demasiados intentos (429)', (tester) async {
      await abrirApp(tester);
      for (var i = 0; i < 5; i++) {
        await iniciarSesion(tester, (Cuentas.adminActivo.$1, 'ClaveMala$i$i$i'));
        await esperar(tester, find.text('Correo o contraseña incorrectos.'));
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).removeCurrentSnackBar();
        await tester.pump();
      }
      await iniciarSesion(tester, Cuentas.adminActivo);
      await esperar(tester, find.text('Espera antes de volver a intentar.'));
      expect(find.text('Portal Corporativo'), findsOneWidget);
    });
  });

  group('Primer ingreso y Términos', () {
    probarApp('colaborador nuevo: lo manda a primer acceso, no a su inicio', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.colaboradorNuevo);
      await esperar(tester, pantallaPrimerAcceso);

      expect(find.text('Términos y Condiciones'), findsOneWidget);
      for (final f in [...menuColaborador, ...menuAdmin]) {
        expect(f, findsNothing);
      }
    });

    probarApp('SIN marcar la casilla: el botón no avanza y la BD no cambia', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.colaboradorNuevo);
      await esperar(tester, pantallaPrimerAcceso);

      await tocar(tester, pantallaPrimerAcceso);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pump();

      expect(pantallaPrimerAcceso, findsOneWidget, reason: 'sigue en primer acceso');
      final fila = await tester.runAsync(() => usuarioEnBd(Cuentas.colaboradorNuevo.$1));
      expect(fila!['isFirstLogin'], isTrue);
      expect(fila['termsAccepted'], isFalse);
    });

    probarApp('intentar saltarse el primer acceso navegando: el router lo devuelve', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.adminNuevo);
      await esperar(tester, pantallaPrimerAcceso);

      router(tester).go(Routes.adminDashboard);
      // Esta pantalla tiene animaciones continuas: se avanza un tiempo fijo
      // en vez de esperar a que "se quede quieta".
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(pantallaPrimerAcceso, findsOneWidget);
      expect(find.text('Dashboard operativo'), findsNothing);
    });

    probarApp('RECHAZAR los Términos: cierra sesión y vuelve al login con aviso', (tester) async {
      final session = await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.colaboradorNuevo);
      await esperar(tester, pantallaPrimerAcceso);

      await tocar(tester, find.text('Rechazar los términos y condiciones'));
      await esperar(tester, find.text('Debes aceptar los Términos y Condiciones para usar TyckOps.'));
      expect(find.text('Portal Corporativo'), findsOneWidget);
      expect(session.isLoggedIn, isFalse);

      final fila = await tester.runAsync(() => usuarioEnBd(Cuentas.colaboradorNuevo.$1));
      expect(fila!['termsAccepted'], isFalse);
    });

    probarApp('ACEPTAR los Términos (colaborador): entra a su pantalla y se guarda en la BD', (tester) async {
      final session = await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.colaboradorNuevo);
      await esperar(tester, pantallaPrimerAcceso);

      await tocar(tester, find.text(textoAceptar));
      await tocar(tester, pantallaPrimerAcceso);
      await esperar(tester, menuColaborador.first);

      verPantallaColaborador();
      expect(session.needsFirstAccess, isFalse);
      final fila = await tester.runAsync(() => usuarioEnBd(Cuentas.colaboradorNuevo.$1));
      expect(fila!['isFirstLogin'], isFalse);
      expect(fila['termsAccepted'], isTrue);
      expect(fila['termsVersion'], 'GA-TOS-2026');
    });

    probarApp('ACEPTAR los Términos (administrador): entra a su pantalla', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.adminNuevo);
      await esperar(tester, pantallaPrimerAcceso);

      await tocar(tester, find.text(textoAceptar));
      await tocar(tester, pantallaPrimerAcceso);
      await esperar(tester, menuAdmin.first);

      verPantallaAdmin();
    });

    probarApp('aceptar y CAMBIAR la clave: la clave nueva queda activa', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.colaboradorNuevo);
      await esperar(tester, pantallaPrimerAcceso);

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), Cuentas.colaboradorNuevo.$2); // temporal actual
      await tester.enterText(campos.at(1), 'ClaveNuevaApp2026');
      await tester.enterText(campos.at(2), 'ClaveNuevaApp2026');
      await tocar(tester, find.text(textoAceptar));
      await tocar(tester, pantallaPrimerAcceso);
      await esperar(tester, menuColaborador.first);

      final fila = await tester.runAsync(() => usuarioEnBd(Cuentas.colaboradorNuevo.$1));
      expect(fila!['passwordHash'], startsWith(r'$2b$12$'));
      expect(fila['passwordHash'], isNot(contains('ClaveNuevaApp2026')));
    });
  });

  group('Cada rol ve SOLO su pantalla', () {
    probarApp('colaborador que intenta abrir pantallas de administrador vuelve a su inicio', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.colaboradorActivo);
      await esperar(tester, menuColaborador.first);

      for (final ruta in [Routes.adminHome, Routes.adminTickets, Routes.adminDashboard]) {
        router(tester).go(ruta);
        await tester.pumpAndSettle();
        verPantallaColaborador();
        expect(find.text('Bandeja de tickets'), findsNothing);
        expect(find.text('Dashboard operativo'), findsNothing);
      }
    });

    probarApp('administrador que intenta abrir pantallas del colaborador vuelve a su inicio', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.adminActivo);
      await esperar(tester, menuAdmin.first);

      for (final ruta in [Routes.workerHome, Routes.workerReport, Routes.workerTickets]) {
        router(tester).go(ruta);
        await tester.pumpAndSettle();
        verPantallaAdmin();
        expect(find.text('Reportar una falla'), findsNothing);
      }
    });

    probarApp('colaborador: sus 3 pestañas muestran sus secciones', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.colaboradorActivo);
      await esperar(tester, menuColaborador.first);

      await tocar(tester, find.text('Reportar falla'));
      await tester.pumpAndSettle();
      expect(find.text('Reportar una falla'), findsOneWidget);
      await tocar(tester, find.text('Mis solicitudes'));
      await tester.pumpAndSettle();
      expect(find.text('Mis Solicitudes'), findsOneWidget);
    });

    probarApp('administrador: sus 3 pestañas muestran sus secciones', (tester) async {
      await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.adminActivo);
      await esperar(tester, menuAdmin.first);

      await tocar(tester, find.text('Tickets'));
      await tester.pumpAndSettle();
      expect(find.text('Bandeja de tickets'), findsOneWidget);
      await tocar(tester, find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard operativo'), findsOneWidget);
    });

    probarApp('cerrar sesión vuelve al login y ya no deja entrar a pantallas internas', (tester) async {
      final session = await abrirApp(tester);
      await iniciarSesion(tester, Cuentas.adminActivo);
      await esperar(tester, menuAdmin.first);

      await tocar(tester, find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Portal Corporativo'), findsOneWidget);
      expect(session.isLoggedIn, isFalse);

      router(tester).go(Routes.adminDashboard);
      await tester.pumpAndSettle();
      expect(find.text('Portal Corporativo'), findsOneWidget);
    });
  });
}
