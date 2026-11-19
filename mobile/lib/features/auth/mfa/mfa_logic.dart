// ¿PARA QUÉ SIRVE?
//   Reúne las reglas pequeñas de la verificación en dos pasos que no dependen
//   del diseño (para poder probarlas fácil).
//
// ¿QUÉ HACE?
//   Limpia un código pegado (deja solo los números) y escribe la cuenta regresiva
//   como "02:59".
//
// ¿CÓMO LO CAMBIO?
//   Si el código cambia de largo (por ejemplo, 8 dígitos), cambia mfaCodeLength
//   aquí Y en el servidor (auth.schema.js). Luego corre test/mfa_test.dart.

/// Largo del código de verificación.
const mfaCodeLength = 6;

/// Deja solo los números de un texto pegado y corta al largo del código.
/// Sirve para pegar "Tu código es 842 913" y obtener "842913".
String sanitizeCode(String raw, {int length = mfaCodeLength}) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length > length ? digits.substring(0, length) : digits;
}

/// Cuenta regresiva en minutos y segundos: 2 min 5 s → "02:05". Nunca negativa.
String formatCountdown(Duration remaining) {
  final total = remaining.isNegative ? 0 : remaining.inSeconds;
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
