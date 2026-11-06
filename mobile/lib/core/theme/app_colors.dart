import 'package:flutter/material.dart';

/// Paleta GA.MA, tomada de los DESIGN.md de Stitch (docs/mockups).
///
/// Regla: ninguna pantalla escribe un color "a mano" (Color(0xFF...)).
/// Siempre se usa AppColors.algo. Así, si cambia un color, se cambia aquí y
/// se actualiza toda la app.
abstract final class AppColors {
  // Marca
  static const red = Color(0xFFD7282F); // CTA principal, urgente, pestaña activa
  static const redPressed = Color(0xFFB51F25); // botón rojo presionado
  static const redSoft = Color(0xFFFFDAD7); // fondo suave (pestaña activa del admin)
  static const onyx = Color(0xFF111111); // textos principales, botón secundario

  // Superficies
  static const white = Color(0xFFFFFFFF); // tarjetas
  static const background = Color(0xFFFAF9F9); // fondo de pantalla
  static const surfaceGray = Color(0xFFF4F4F4); // inputs, chips neutros
  static const border = Color(0xFFE5E5E5); // bordes y divisores

  // Texto
  static const textPrimary = onyx;
  static const textSecondary = Color(0xFF8A8A8A); // fechas, ayudas, inactivos

  // Funcionales
  static const warning = Color(0xFFF2B705); // duplicados, alertas
  static const error = Color(0xFFBA1A1A);
  static const success = Color(0xFF16A34A);
}
