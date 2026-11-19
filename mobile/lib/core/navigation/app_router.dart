// ¿PARA QUÉ SIRVE?
//   Es el mapa de pantallas de la app: qué pantalla corresponde a cada dirección.
//
// ¿QUÉ HACE?
//   Define las rutas del colaborador y del administrador, y cada vez que cambia la
//   sesión decide a dónde mandarte (login, primer acceso o tu inicio).
//
// ¿CÓMO LO CAMBIO?
//   Para agregar una pantalla nueva, súmala aquí con su ruta (y la ruta en
//   routes.dart). Las reglas de quién puede entrar están en routes.dart.

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/ticket.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../features/auth/auth_session.dart';
import '../../features/auth/first_access_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/mfa/mfa_screen.dart';
import '../../features/shared/components_gallery_screen.dart';
import '../../features/shared/placeholder_screen.dart';
import '../../features/worker/home/worker_home_screen.dart';
import '../../features/worker/my_tickets_store.dart';
import '../../features/worker/report/report_fault_screen.dart';
import '../../features/worker/report/report_sent_screen.dart';
import '../../features/worker/tickets/my_tickets_screen.dart';
import '../../features/worker/tickets/ticket_detail_screen.dart';
import 'role_shells.dart';
import 'routes.dart';

/// Mapa de navegación de la app.
///
/// Este mapa "escucha" a la sesión: cada vez que alguien entra o sale, vuelve
/// a revisar a qué pantalla debe ir la persona (login, primer acceso o su inicio).
GoRouter createRouter(
  AuthSession session,
  AuthRepository authRepository,
  MyTicketsStore ticketsStore,
  ReportRepository reportRepository,
) {
  return GoRouter(
    initialLocation: Routes.login,
    refreshListenable: session,
    redirect: (context, state) => redirectFor(
      loggedIn: session.isLoggedIn,
      role: session.role,
      location: state.matchedLocation,
      needsFirstAccess: session.needsFirstAccess,
      mfaPending: session.mfaPending,
      allowDevRoutes: kDebugMode,
    ),
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) =>
            LoginScreen(session: session, authRepository: authRepository),
      ),
      GoRoute(
        path: Routes.firstAccess,
        builder: (context, state) =>
            FirstAccessScreen(session: session, authRepository: authRepository),
      ),
      // T8 · Verificación en dos pasos (colaborador y, en la T12, administrador).
      GoRoute(
        path: Routes.mfaVerification,
        builder: (context, state) => MfaScreen(session: session, authRepository: authRepository),
      ),
      if (kDebugMode)
        GoRoute(
          path: Routes.devComponents,
          builder: (context, state) => const ComponentsGalleryScreen(),
        ),

      // ===== Colaborador =====
      // Confirmación del reporte (T6): fuera de las pestañas, sin barra inferior.
      // Solo se llega desde el formulario con el ticket recién creado.
      GoRoute(
        path: Routes.workerReportSent,
        redirect: (context, state) => state.extra is Ticket ? null : Routes.workerHome,
        builder: (context, state) => ReportSentScreen(ticket: state.extra! as Ticket),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            WorkerShell(navigationShell: shell, ticketsStore: ticketsStore),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.workerHome,
              builder: (context, state) =>
                  WorkerHomeScreen(session: session, store: ticketsStore),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.workerReport,
              builder: (context, state) => ReportFaultScreen(
                session: session,
                store: ticketsStore,
                reports: reportRepository,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.workerTickets,
              // T7 · Lista "Mis Solicitudes" (usa los mismos datos que el home).
              builder: (context, state) => MyTicketsScreen(session: session, store: ticketsStore),
              routes: [
                // T7 · Detalle del ticket. Un id con caracteres raros vuelve a la
                // lista; además, el servidor responde 404 si el ticket no es tuyo.
                GoRoute(
                  path: ':ticketId',
                  redirect: (context, state) =>
                      Ticket.isSafeId(state.pathParameters['ticketId'] ?? '') ? null : Routes.workerTickets,
                  builder: (context, state) => TicketDetailScreen(
                    // Al abrir un ticket distinto, la pantalla se carga de cero (no reusa el anterior).
                    key: ValueKey(state.pathParameters['ticketId']),
                    ticketId: state.pathParameters['ticketId']!,
                    repository: ticketsStore.repository,
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),

      // ===== Administrador =====
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdminShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.adminHome,
              builder: (context, state) =>
                  PlaceholderScreen(title: 'Inicio', task: 'T11', onSignOut: session.signOut),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.adminTickets,
              builder: (context, state) =>
                  const PlaceholderScreen(title: 'Bandeja de tickets', task: 'T12'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.adminDashboard,
              builder: (context, state) =>
                  const PlaceholderScreen(title: 'Dashboard operativo', task: 'T14'),
            ),
          ]),
        ],
      ),
    ],
  );
}
