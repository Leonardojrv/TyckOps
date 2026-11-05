import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant {
  primary, // rojo: acción principal ("Iniciar sesión", "Crear reporte")
  secondary, // negro: acción alternativa ("Nueva")
  outline, // borde gris: acción neutra ("Cancelar")
  light, // blanco sobre fondo oscuro ("Crear reporte" del home)
}

/// Botón estándar GA.MA: 48 px de alto, radio 12 px.
///
/// Si [onPressed] es null, el botón queda deshabilitado (así se bloquea
/// "Rechazar" hasta escribir el motivo, en la T13).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading; // muestra un spinner y evita doble envío
  final bool expand; // true = ocupa todo el ancho

  @override
  Widget build(BuildContext context) {
    final (background, foreground, pressed, borderColor) = switch (variant) {
      AppButtonVariant.primary =>
        (AppColors.red, AppColors.white, AppColors.redPressed, null),
      AppButtonVariant.secondary =>
        (AppColors.onyx, AppColors.white, const Color(0xFF2A2A2A), null),
      AppButtonVariant.outline =>
        (Colors.transparent, AppColors.onyx, AppColors.surfaceGray, AppColors.border),
      AppButtonVariant.light =>
        (AppColors.white, AppColors.onyx, AppColors.surfaceGray, null),
    };

    final enabled = onPressed != null && !isLoading;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(expand ? double.infinity : 0, AppTheme.controlHeight),
      ),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(AppTypography.labelLarge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !isLoading) {
          return variant == AppButtonVariant.outline ? Colors.transparent : AppColors.border;
        }
        if (states.contains(WidgetState.pressed)) return pressed;
        return background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !isLoading
            ? AppColors.textSecondary
            : foreground,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );

    final child = isLoading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[Icon(leadingIcon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: 20)],
            ],
          );

    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      child: child,
    );
  }
}
