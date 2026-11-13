import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'worker_tokens.dart';

typedef _C = WorkerColors;

/// Barra inferior del colaborador (mockup home_inicio): Inicio ·
/// Reportar falla · Mis solicitudes. Pestaña activa en rojo, ícono relleno
/// y un punto debajo. El número gris son las solicitudes en curso.
class WorkerBottomNav extends StatelessWidget {
  const WorkerBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.activeTickets = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int activeTickets;

  static const _items = [
    (Symbols.home, 'Inicio'),
    (Symbols.build_circle, 'Reportar falla'),
    (Symbols.assignment_turned_in, 'Mis solicitudes'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _C.surface.withValues(alpha: 0.95),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, -1))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavTab(
                      icon: _items[i].$1,
                      label: _items[i].$2,
                      active: i == currentIndex,
                      badge: i == 2 ? activeTickets : 0,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _C.primaryContainer : _C.secondary;
    final badgeText = badge > 99 ? '99+' : '$badge';
    return Semantics(
      button: true,
      selected: active,
      label: badge > 0 ? '$label, $badge en curso' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 24, fill: active ? 1 : 0, color: color),
                    if (badge > 0)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: Container(
                          height: 14,
                          constraints: const BoxConstraints(minWidth: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _C.containerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: WorkerText.caption(_C.onSurface).copyWith(
                              fontSize: 9,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WorkerText.caption(color).copyWith(
                    letterSpacing: -0.1,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 4,
              child: AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
