import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Tema global de la app. Se aplica una sola vez en app.dart y todos los
/// widgets de Material (botones, inputs, tarjetas) lo heredan.
abstract final class AppTheme {
  static const radiusControl = 12.0; // botones e inputs (decisión 05-11-2026)
  static const radiusCard = 16.0; // tarjetas
  static const controlHeight = 48.0; // área táctil mínima

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.red,
      onPrimary: AppColors.white,
      secondary: AppColors.onyx,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.white,
      outline: AppColors.border,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme,
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Gris en reposo, blanco al enfocar (como en los mockups).
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? AppColors.white
              : AppColors.surfaceGray,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.red, 1.5),
        errorBorder: inputBorder(AppColors.red, 1.5),
        focusedErrorBorder: inputBorder(AppColors.red, 1.5),
        errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.red),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.onyx,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.red),
    );
  }
}
