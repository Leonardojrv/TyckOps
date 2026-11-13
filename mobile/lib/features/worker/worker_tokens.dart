import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores exactos de los mockups del colaborador (tailwind.config de Stitch,
/// docs/mockups/colaborador). Las pantallas del colaborador usan estos.
abstract final class WorkerColors {
  static const surface = Color(0xFFF9F9F9);
  static const white = Color(0xFFFFFFFF); // surface-container-lowest
  static const containerLow = Color(0xFFF3F3F3);
  static const container = Color(0xFFEEEEEE);
  static const containerHigh = Color(0xFFE8E8E8);
  static const containerHighest = Color(0xFFE2E2E2);
  static const onSurface = Color(0xFF1A1C1C);
  static const secondary = Color(0xFF5F5E5E);
  static const secondaryContainer = Color(0xFFE5E2E1);
  static const onSecondaryContainer = Color(0xFF656464);
  static const secondaryFixed = Color(0xFFE5E2E1);
  static const outline = Color(0xFF906F6C);
  static const primaryContainer = Color(0xFFD7282F); // rojo GA.MA
  static const error = Color(0xFFBA1A1A);
  static const inverseSurface = Color(0xFF2F3131);
  static const inverseOnSurface = Color(0xFFF1F1F1);
}

/// Escala tipográfica del mockup (Inter).
abstract final class WorkerText {
  static TextStyle _inter(double size, double height, FontWeight weight, [double tracking = 0]) =>
      GoogleFonts.inter(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: tracking * size,
        color: WorkerColors.onSurface,
      );

  static TextStyle headlineLg([Color? c]) => _inter(24, 30, FontWeight.w600, -0.015).copyWith(color: c);
  static TextStyle headlineSm([Color? c]) => _inter(18, 24, FontWeight.w600).copyWith(color: c);
  static TextStyle bodyMd([Color? c]) => _inter(14, 20, FontWeight.w400).copyWith(color: c);
  static TextStyle bodySm([Color? c]) => _inter(13, 18, FontWeight.w400).copyWith(color: c);
  static TextStyle labelLg([Color? c]) => _inter(14, 18, FontWeight.w600, 0.01).copyWith(color: c);
  static TextStyle labelMd([Color? c]) => _inter(12, 16, FontWeight.w600, 0.02).copyWith(color: c);
  static TextStyle labelSm([Color? c]) => _inter(11, 14, FontWeight.w500, 0.03).copyWith(color: c);
  static TextStyle caption([Color? c]) => _inter(10, 12, FontWeight.w500, 0.04).copyWith(color: c);
}

/// Sombra "shadow-sm" de Tailwind.
const workerShadowSm = [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))];
