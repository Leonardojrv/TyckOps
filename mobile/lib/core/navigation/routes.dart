// ¿PARA QUÉ SIRVE?
//   Junta todas las direcciones de la app y las reglas de quién puede verlas.
//
// ¿QUÉ HACE?
//   Guarda las rutas como constantes (nada de textos sueltos) y decide si alguien
//   debe ir al login, al primer acceso o a su inicio según su sesión y su rol.
//
// ¿CÓMO LO CAMBIO?
//   Si agregas una ruta, ponla aquí. Si cambias una regla de acceso, actualiza
//   test/route_guard_test.dart. Ojo: esto solo esconde pantallas; quien protege
//   los datos de verdad es el servidor.

import '../../data/models/user_role.dart';

/// Todas las rutas de la app en un solo lugar (nada de textos sueltos).
abstract final class Routes {
  static const login = '/login';
  static const firstAccess = '/primer-acceso';
  static const adminPasswordChange = '/cambio-contrasena'; // primer ingreso del administrador (T12)
  static const mfaVerification = '/verificacion'; // verificación en dos pasos (T8)
  static const devComponents = '/dev/componentes';

  // Colaborador
  static const workerHome = '/worker/inicio';
  static const workerReport = '/worker/reportar';
  static const workerReportSent = '/worker/reporte-enviado'; // confirmación (T6)
  static const workerTickets = '/worker/solicitudes';
  /// [focusComments]: al abrir desde "Nuevo comentario" (T11), baja hasta los comentarios.
  static String workerTicketDetail(String id, {bool focusComments = false}) =>
      '$workerTickets/${Uri.encodeComponent(id)}${focusComments ? '?ver=comentarios' : ''}';
  static const workerHistory = '$workerTickets/historial'; // historial con filtros (T9)
  static const workerNotifications = '$workerHome/notificaciones'; // campana (T11)

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
/// de verdad es el servidor, que revisa el rol en CADA una de sus rutas.
String? redirectFor({
  required bool loggedIn,
  required UserRole? role,
  required String location,
  bool needsFirstAccess = false,
  bool mfaPending = false,
  bool allowDevRoutes = false,
}) {
  final isPublic = location == Routes.login ||
      (allowDevRoutes && location.startsWith('/dev'));

  // T8: mientras haya una verificación en dos pasos pendiente, la persona solo
  // puede estar en esa pantalla. Ninguna ruta interna se abre sin el código.
  if (mfaPending) return location == Routes.mfaVerification ? null : Routes.mfaVerification;
  // Sin verificación pendiente, esa pantalla no tiene sentido: al login o al inicio.
  if (location == Routes.mfaVerification) {
    return loggedIn && role != null ? Routes.homeFor(role) : Routes.login;
  }

  if (!loggedIn || role == null) return isPublic ? null : Routes.login;

  // RF-02 / T12: hasta terminar su configuración inicial, la persona solo puede
  // estar en SU pantalla: el colaborador en "Primer acceso" (con términos) y el
  // administrador en "Cambio de contraseña" (sin términos, después del MFA).
  if (needsFirstAccess) {
    final setup = role == UserRole.admin ? Routes.adminPasswordChange : Routes.firstAccess;
    return location == setup ? null : setup;
  }

  final home = Routes.homeFor(role);
  if (location == Routes.firstAccess || location == Routes.adminPasswordChange) return home;
  if (location == Routes.login) return home;
  if (role == UserRole.worker && location.startsWith('/admin')) return home;
  if (role == UserRole.admin && location.startsWith('/worker')) return home;
  return null;
}
