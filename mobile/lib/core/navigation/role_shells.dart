import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/worker/my_tickets_store.dart';
import '../../features/worker/worker_bottom_nav.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ticket_check_icon.dart';

/// "Cascarón" del colaborador: la pantalla de la pestaña actual + su barra
/// inferior (Inicio · Reportar falla · Mis solicitudes).
class WorkerShell extends StatelessWidget {
  const WorkerShell({super.key, required this.navigationShell, required this.ticketsStore});

  final StatefulNavigationShell navigationShell;
  final MyTicketsStore ticketsStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      // El número sobre "Mis solicitudes" se actualiza solo cuando cambian los tickets.
      bottomNavigationBar: ListenableBuilder(
        listenable: ticketsStore,
        builder: (context, _) => WorkerBottomNav(
          currentIndex: navigationShell.currentIndex,
          onTap: (i) => _goTo(navigationShell, i),
          activeTickets: ticketsStore.data?.inAttention ?? 0,
        ),
      ),
    );
  }
}

/// "Cascarón" del administrador (Inicio · Tickets · Dashboard).
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => _goTo(navigationShell, i),
        // Mismo estilo que el colaborador (decisión 05-11-2026).
        indicatorStyle: NavIndicatorStyle.dot,
        items: [
          const AppNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Inicio'),
          AppNavItem(
            label: 'Tickets',
            // Ícono personalizado del mockup: ticket con check.
            iconBuilder: (color, active) => TicketCheckIcon(color: color, filled: active),
          ),
          const AppNavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'Dashboard'),
        ],
      ),
    );
  }
}

/// Cambia de pestaña. Si tocas la pestaña en la que ya estás, vuelve a su
/// pantalla inicial (como en Instagram o WhatsApp).
void _goTo(StatefulNavigationShell shell, int index) {
  shell.goBranch(index, initialLocation: index == shell.currentIndex);
}
