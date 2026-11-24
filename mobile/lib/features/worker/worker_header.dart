// ¿PARA QUÉ SIRVE?
//   Es el encabezado de las pantallas del colaborador.
//
// ¿QUÉ HACE?
//   Muestra "SERVICIOS GENERALES", el título, la campana y el chip "Colaborador"
//   (que al tocarlo permite cerrar sesión).
//
// ¿CÓMO LO CAMBIO?
//   La campana abre "Notificaciones" (T11) y muestra cuántos avisos faltan por leer.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/navigation/routes.dart';
import 'notifications/notifications_store.dart';

import 'worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

/// Encabezado de las pantallas del colaborador (mockups home_inicio y
/// reportar_una_falla): sección, título, campana y chip "Colaborador".
class WorkerHeader extends StatelessWidget implements PreferredSizeWidget {
  const WorkerHeader({super.key, required this.title, required this.onSignOut});

  final String title; // "Inicio", "Reportar Falla"...

  final Future<void> Function() onSignOut;

  @override
  Size get preferredSize => const Size.fromHeight(64);


  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _C.surface.withValues(alpha: 0.9),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SERVICIOS GENERALES',
                        style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.55),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(title, style: _T.headlineSm().copyWith(height: 1.25), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                _Bell(unread: NotificationsScope.maybeOf(context)?.unread ?? 0),
                const SizedBox(width: 4),
                _RoleChip(onSignOut: onSignOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// T11 · Campana con el número de avisos sin leer; abre "Notificaciones".
class _Bell extends StatelessWidget {
  const _Bell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: unread == 0 ? 'Notificaciones' : 'Notificaciones, $unread sin leer',
      onPressed: () => context.go(Routes.workerNotifications),
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: _C.primaryContainer,
        textColor: _C.white,
        child: Icon(Symbols.notifications, size: 24, color: _C.onSurface, fill: unread > 0 ? 1 : 0),
      ),
    );
  }
}

/// Chip "Colaborador". Al tocarlo ofrece cerrar sesión (el mockup no tiene
/// otro lugar para hacerlo).
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Opciones de la cuenta',
      position: PopupMenuPosition.under,
      color: _C.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: onSignOut,
          child: Row(
            children: [
              const Icon(Symbols.logout, size: 20, color: _C.onSurface),
              const SizedBox(width: 12),
              Text('Cerrar sesión', style: _T.bodyMd()),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(999)),
        child: Text('Colaborador', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: -0.1)),
      ),
    );
  }
}
