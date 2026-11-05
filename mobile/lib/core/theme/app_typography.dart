import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Escala tipográfica Inter, según el DESIGN.md.
///
/// En Flutter, `height` no es en píxeles: es un multiplicador del tamaño.
/// Por eso un "lineHeight: 34px" con "fontSize: 28px" se escribe 34 / 28.
/// Lo mismo con letterSpacing: "-0.02em" en 28 px = -0.02 * 28 = -0.56 px.
abstract final class AppTypography {
  static TextStyle _inter(double size, FontWeight weight, double lineHeight,
          [double letterSpacingEm = 0]) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        height: lineHeight / size,
        letterSpacing: letterSpacingEm * size,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineLarge => _inter(28, FontWeight.w700, 34, -0.02);
  static TextStyle get headlineMedium => _inter(20, FontWeight.w600, 26, -0.01);
  static TextStyle get headlineSmall => _inter(18, FontWeight.w600, 24);
  static TextStyle get bodyLarge => _inter(16, FontWeight.w400, 24);
  static TextStyle get bodyMedium => _inter(14, FontWeight.w400, 20);
  static TextStyle get bodySmall => _inter(12, FontWeight.w400, 16);
  static TextStyle get labelLarge => _inter(15, FontWeight.w600, 20, 0.01);
  static TextStyle get labelMedium => _inter(12, FontWeight.w600, 16, 0.02);
  static TextStyle get labelSmall => _inter(11, FontWeight.w700, 14, 0.04);

  /// Se conecta con el TextTheme de Material, para que
  /// `Theme.of(context).textTheme.bodyMedium` devuelva nuestra fuente.
  static TextTheme get textTheme => TextTheme(
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: headlineMedium,
        titleMedium: headlineSmall,
        titleSmall: labelLarge,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
