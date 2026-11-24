// ¿PARA QUÉ SIRVE?
//   Revisa lo que escribes en los formularios antes de enviarlo.
//
// ¿QUÉ HACE?
//   Avisa si falta un campo, si el correo no es de un dominio permitido
//   (@gamaitaly.cl, @outlook.com o @gmail.com) o si la contraseña
//   nueva es débil, y calcula el medidor de seguridad de la contraseña.
//
// ¿CÓMO LO CAMBIO?
//   Si cambia una regla (por ejemplo, contraseñas de 10 caracteres), cámbiala aquí
//   Y TAMBIÉN en el servidor, porque la app se puede saltar. Luego corre
//   test/validators_test.dart.

/// Validaciones de formularios. Cada función devuelve:
/// - null  → el valor es válido
/// - texto → el mensaje de error que se muestra bajo el campo
///
/// Seguridad: validar en la app solo mejora la experiencia del usuario.
/// Cualquiera puede saltarse la app y llamar directo a la API, así que el
/// backend SIEMPRE debe repetir estas validaciones.
abstract final class Validators {
  /// Dominios con los que se puede iniciar sesión (colaborador y administrador).
  /// Para agregar o quitar uno, cámbialo aquí Y en el servidor
  /// (DOMINIOS_PERMITIDOS en backend/src/modules/auth/auth.schema.js).
  /// Este orden es el que se muestra en el aviso del login y en el error.
  static const allowedDomains = ['gmail.com', 'outlook.com', 'gamaitaly.cl'];

  /// Los dominios escritos para mostrarlos: "@gmail.com, @outlook.com o @gamaitaly.cl".
  static String get allowedDomainsText {
    final list = allowedDomains.map((d) => '@$d').toList();
    return '${list.sublist(0, list.length - 1).join(', ')} o ${list.last}';
  }

  // Parte de antes de la @ (letras, números y . _ % + -) y un dominio cualquiera;
  // luego se revisa que ese dominio esté EXACTO en la lista (no "termina en").
  static final _emailRegex = RegExp(r'^[a-z0-9._%+-]+@([a-z0-9.-]+)$');

  /// Campo obligatorio. El mensaje se escribe completo para que la frase
  /// siempre concuerde ("Ingresa tu contraseña", no "La contraseña es obligatorio").
  static String? required(String? value, {String message = 'Completa este campo'}) =>
      (value == null || value.trim().isEmpty) ? message : null;

  /// RF-01: solo correos de los dominios permitidos.
  static String? corporateEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo';
    final match = _emailRegex.firstMatch(email);
    if (match == null || !allowedDomains.contains(match.group(1))) {
      return 'Usa un correo $allowedDomainsText';
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
