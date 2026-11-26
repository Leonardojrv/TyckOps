// ¿PARA QUÉ SIRVE?
//   Prueba el ingreso del administrador (T12): login → código MFA → cambio de
//   contraseña en el primer ingreso → Home.
//
// ¿QUÉ HACE?
//   Revisa que el administrador vaya primero al código, que después (solo la
//   primera vez) quede en "Cambio de Contraseña" sin poder abrir otras pantallas,
//   que esa pantalla no muestre términos y que al terminar llegue a su Home.
//
// ¿CÓMO LO CAMBIO?
//   Si cambia el orden del ingreso o los textos del mockup, ajusta esta prueba y
//   corre `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/navigation/routes.dart';
import 'package:tyckops/core/network/token_storage.dart';
import 'package:tyckops/data/models/app_user.dart';
import 'package:tyckops/data/models/user_role.dart';
import 'package:tyckops/data/repositories/auth_repository.dart';
import 'package:tyckops/features/auth/auth_session.dart';
import 'package:tyckops/features/auth/first_access_screen.dart';

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
  group('Rutas del primer ingreso', () {
    test('el administrador nuevo solo puede estar en "Cambio de Contraseña"', () {
      for (final ruta in [Routes.adminHome, Routes.adminTickets, Routes.firstAccess, Routes.workerHome]) {
        expect(
          redirectFor(loggedIn: true, role: UserRole.admin, location: ruta, needsFirstAccess: true),
          Routes.adminPasswordChange,
        );
      }
      expect(
        redirectFor(loggedIn: true, role: UserRole.admin, location: Routes.adminPasswordChange, needsFirstAccess: true),
        isNull,
      );
      // Ya configurado: esa pantalla lleva a su Home.
      expect(redirectFor(loggedIn: true, role: UserRole.admin, location: Routes.adminPasswordChange), Routes.adminHome);
    });

    test('el colaborador sigue yendo a su primer acceso con términos', () {
      expect(
        redirectFor(loggedIn: true, role: UserRole.worker, location: Routes.workerHome, needsFirstAccess: true),
        Routes.firstAccess,
      );
    });
  });

  test('al administrador no se le exigen Términos: solo su primer ingreso', () async {
    final session = AuthSession(_MemoryTokenStorage());
    await session.signIn(
      const AppUser(id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', role: UserRole.admin, termsAccepted: false),
      't',
    );
    expect(session.needsFirstAccess, isFalse);
    await session.signIn(
      const AppUser(id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', role: UserRole.admin, isFirstLogin: true),
      't',
    );
    expect(session.needsFirstAccess, isTrue);
  });

  test('modo de prueba: login → código → cambio de contraseña → Home', () async {
    final repo = FakeAuthRepository();
    final session = AuthSession(_MemoryTokenStorage());

    final login = await repo.login(email: 'admin@gamaitaly.cl', password: 'prueba1234');
    expect(login.needsMfa, isTrue, reason: 'el administrador siempre va primero al código');

    final verified = await repo.verifyMfa(login.mfa!, FakeAuthRepository.devCode);
    await session.signIn(verified.user, verified.token);
    expect(session.needsFirstAccess, isTrue, reason: 'primer ingreso: pasa al cambio de contraseña');

    final done = await repo.completeAdminFirstAccess(currentPassword: 'prueba1234', newPassword: 'NuevaClave2026');
    await session.signIn(done.user, done.token);
    expect(session.needsFirstAccess, isFalse);
    expect(redirectFor(loggedIn: true, role: session.role, location: Routes.adminPasswordChange), Routes.adminHome);

    // La próxima vez: código y directo al Home.
    final again = await repo.verifyMfa((await repo.login(email: 'admin@gamaitaly.cl', password: 'x123')).mfa!, '123456');
    expect(again.user.isFirstLogin, isFalse);
  });

  testWidgets('la pantalla del administrador sigue su mockup y no tiene términos', (tester) async {
    tester.view.physicalSize = const Size(1500, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = AuthSession(_MemoryTokenStorage());
    await session.signIn(
      const AppUser(id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', role: UserRole.admin, isFirstLogin: true),
      't',
    );
    await tester.pumpWidget(MaterialApp(
      home: FirstAccessScreen(session: session, authRepository: FakeAuthRepository(), adminMode: true),
    ));
    await tester.pump();

    expect(find.text('Cambio de Contraseña'), findsOneWidget);
    expect(find.text('Rol Administrador'), findsOneWidget);
    expect(find.text('Panel de Administración - Seguridad de Cuenta'), findsOneWidget);
    expect(find.textContaining('Términos'), findsNothing);
    // Rojo: "Actualizar contraseña". Gris: "Mantener contraseña actual".
    expect(find.text('Actualizar contraseña'), findsOneWidget);
    expect(find.text('Mantener contraseña actual'), findsOneWidget);

    // "Actualizar" sin escribir la nueva: pide escribirla (no cambia nada).
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pump();
    expect(find.textContaining('Ingresa tu nueva contraseña o elige'), findsOneWidget);
    expect(session.needsFirstAccess, isTrue);
  });
}
