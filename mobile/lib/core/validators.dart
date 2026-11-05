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

  static String? required(String? value, {String field = 'Este campo'}) =>
      (value == null || value.trim().isEmpty) ? '$field es obligatorio' : null;

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
}
