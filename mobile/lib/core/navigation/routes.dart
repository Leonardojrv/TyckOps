import '../../data/models/user_role.dart';

/// Todas las rutas de la app en un solo lugar (nada de textos sueltos).
abstract final class Routes {
  static const login = '/login';
  static const devComponents = '/dev/componentes';

  // Colaborador
  static const workerHome = '/worker/inicio';
  static const workerReport = '/worker/reportar';
  static const workerTickets = '/worker/solicitudes';

  // Administrador
  static const adminHome = '/admin/inicio';
  static const adminTickets = '/admin/tickets';
  static const adminDashboard = '/admin/dashboard';

  static String homeFor(UserRole role) =>
      role == UserRole.admin ? adminHome : workerHome;
}

/// Guardia por rol: decide si hay que redirigir al usuario.
/// Devuelve null si puede quedarse donde está.
///
/// Es una función pura (sin Flutter adentro), por eso se puede probar con
/// un test simple (test/route_guard_test.dart).
///
/// Seguridad: esta guardia solo esconde pantallas. Quien protege los datos
/// de verdad es el backend, que debe revisar el rol en CADA endpoint.
String? redirectFor({
  required bool loggedIn,
  required UserRole? role,
  required String location,
  bool allowDevRoutes = false,
}) {
  final isPublic = location == Routes.login ||
      (allowDevRoutes && location.startsWith('/dev'));

  if (!loggedIn || role == null) return isPublic ? null : Routes.login;

  final home = Routes.homeFor(role);
  if (location == Routes.login) return home;
  if (role == UserRole.worker && location.startsWith('/admin')) return home;
  if (role == UserRole.admin && location.startsWith('/worker')) return home;
  return null;
}
