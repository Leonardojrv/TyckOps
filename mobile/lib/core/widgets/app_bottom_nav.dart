import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Cómo se marca la pestaña activa (cada rol tiene su estilo en los mockups).
enum NavIndicatorStyle {
  dot, // colaborador: ícono rojo + punto rojo debajo
  pill, // administrador: ícono rojo sobre una píldora rosada
}

class AppNavItem {
  const AppNavItem({
    this.icon,
    this.activeIcon,
    this.iconBuilder,
    required this.label,
    this.badgeCount = 0,
  }) : assert(iconBuilder != null || (icon != null && activeIcon != null),
            'Usa icon + activeIcon, o bien iconBuilder');

  final IconData? icon;
  final IconData? activeIcon;

  /// Para íconos dibujados a mano (como el ticket del administrador).
  /// Recibe el color y si la pestaña está activa.
  final Widget Function(Color color, bool active)? iconBuilder;

  final String label;
  final int badgeCount; // número rojo sobre el ícono (0 = no se muestra)
}

/// Barra de navegación inferior de 3 pestañas.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.indicatorStyle = NavIndicatorStyle.dot,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final NavIndicatorStyle indicatorStyle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false, // respeta la barra de gestos de Android / iPhone
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    active: i == currentIndex,
                    style: indicatorStyle,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.style, required this.onTap});

  final AppNavItem item;
  final bool active;
  final NavIndicatorStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.red : AppColors.textSecondary;

    Widget icon = item.iconBuilder != null
        ? item.iconBuilder!(color, active)
        : Icon(active ? item.activeIcon : item.icon, color: color, size: 24);
    if (item.badgeCount > 0) {
      icon = Badge(
        label: Text('${item.badgeCount}'),
        backgroundColor: AppColors.red,
        child: icon,
      );
    }
    if (style == NavIndicatorStyle.pill) {
      icon = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.redSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: icon,
      );
    }

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (style == NavIndicatorStyle.dot) ...[
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? AppColors.red : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
