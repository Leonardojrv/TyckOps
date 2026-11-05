import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/navigation/routes.dart';
import 'package:tyckops/data/models/user_role.dart';

void main() {
  group('Guardia de rutas por rol', () {
    test('sin sesión, cualquier pantalla manda al login', () {
      expect(redirectFor(loggedIn: false, role: null, location: Routes.workerHome), Routes.login);
      expect(redirectFor(loggedIn: false, role: null, location: Routes.adminDashboard), Routes.login);
    });

    test('sin sesión, el login se puede ver', () {
      expect(redirectFor(loggedIn: false, role: null, location: Routes.login), isNull);
    });

    test('con sesión, el login redirige al home de su rol', () {
      expect(redirectFor(loggedIn: true, role: UserRole.worker, location: Routes.login), Routes.workerHome);
      expect(redirectFor(loggedIn: true, role: UserRole.admin, location: Routes.login), Routes.adminHome);
    });

    test('un colaborador no puede entrar a pantallas de administrador', () {
      expect(redirectFor(loggedIn: true, role: UserRole.worker, location: Routes.adminDashboard), Routes.workerHome);
    });

    test('un administrador no entra a las pantallas del colaborador', () {
      expect(redirectFor(loggedIn: true, role: UserRole.admin, location: Routes.workerTickets), Routes.adminHome);
    });

    test('las rutas de desarrollo solo existen si se permiten', () {
      expect(redirectFor(loggedIn: false, role: null, location: Routes.devComponents), Routes.login);
      expect(
        redirectFor(loggedIn: false, role: null, location: Routes.devComponents, allowDevRoutes: true),
        isNull,
      );
    });
  });
}
