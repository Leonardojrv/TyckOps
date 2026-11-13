import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/ticket.dart';
import '../../data/repositories/auth_repository.dart';
import '../../features/auth/auth_session.dart';
import '../../features/auth/first_access_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/shared/components_gallery_screen.dart';
import '../../features/shared/placeholder_screen.dart';
import '../../features/worker/home/worker_home_screen.dart';
import '../../features/worker/my_tickets_store.dart';
import 'role_shells.dart';
import 'routes.dart';

/// Mapa de navegación de la app.
///
/// [refreshListenable] hace que, cuando la sesión cambia (login o logout),
/// el router vuelva a ejecutar [redirect] y lleve al usuario a donde debe.
GoRouter createRouter(
  AuthSession session,
  AuthRepository authRepository,
  MyTicketsStore ticketsStore,
) {
  return GoRouter(
    initialLocation: Routes.login,
    refreshListenable: session,
    redirect: (context, state) => redirectFor(
      loggedIn: session.isLoggedIn,
      role: session.role,
      location: state.matchedLocation,
      needsFirstAccess: session.needsFirstAccess,
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
      if (kDebugMode)
        GoRoute(
          path: Routes.devComponents,
          builder: (context, state) => const ComponentsGalleryScreen(),
        ),

      // ===== Colaborador =====
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
              builder: (context, state) =>
                  const PlaceholderScreen(title: 'Reportar una falla', task: 'T6'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.workerTickets,
              builder: (context, state) =>
                  const PlaceholderScreen(title: 'Mis Solicitudes', task: 'T7'),
              routes: [
                // Detalle del ticket (T7). El servidor valida que sea del usuario.
                GoRoute(
                  path: ':ticketId',
                  redirect: (context, state) =>
                      Ticket.isSafeId(state.pathParameters['ticketId'] ?? '') ? null : Routes.workerTickets,
                  builder: (context, state) => PlaceholderScreen(
                    title: 'Detalle de la solicitud',
                    task: 'T7',
                    onBack: () => context.go(Routes.workerTickets),
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
