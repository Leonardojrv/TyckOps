/// Validaciones de formularios. Cada función devuelve:
/// - null  → el valor es válido
/// - texto → el mensaje de error que se muestra bajo el campo
///
/// Seguridad: validar en la app solo mejora la experiencia del usuario.
/// Cualquiera puede saltarse la app y llamar directo a la API, así que el
/// backend SIEMPRE debe repetir estas validaciones.
abstract final class Validators {
  static const corporateDomain = 'gamaitaly.cl';
  static final _emailRegex = RegExp(r'^[a-z0-9._%+-]+@gamaitaly\.cl$');

  /// Campo obligatorio. El mensaje se escribe completo para que la frase
  /// siempre concuerde ("Ingresa tu contraseña", no "La contraseña es obligatorio").
  static String? required(String? value, {String message = 'Completa este campo'}) =>
      (value == null || value.trim().isEmpty) ? message : null;

  /// RF-01: solo correos corporativos.
  static String? corporateEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo corporativo';
    if (!_emailRegex.hasMatch(email)) {
      return 'Usa tu correo corporativo (@$corporateDomain)';
    }
    return null;
  }

  /// RF-02: la nueva contraseña es opcional. Vacía = mantener la actual.
  /// Criterio del mockup: mínimo 8 caracteres, con letras y números.
  static String? optionalNewPassword(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length < 8) return 'Debe tener al menos 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
      return 'Debe combinar letras y números';
    }
    return null;
  }

  static String? confirmPassword(String? value, String newPassword) {
    if (newPassword.isEmpty) return null;
    return value == newPassword ? null : 'Las contraseñas no coinciden';
  }

  /// Medidor del mockup: 1 punto por cada criterio cumplido
  /// (8+ caracteres, mayúscula, número, símbolo).
  static PasswordStrength passwordStrength(String value) {
    if (value.isEmpty) return PasswordStrength.none;
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    if (score <= 1) return PasswordStrength.low;
    if (score <= 3) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }
}

enum PasswordStrength { none, low, medium, strong }
