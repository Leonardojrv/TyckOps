// ¿PARA QUÉ SIRVE?
//   Guarda la "llave" de tu sesión (el token) para que no tengas que iniciar
//   sesión cada vez que abres la app.
//
// ¿QUÉ HACE?
//   Guarda, lee y borra el token usando el almacenamiento cifrado del teléfono
//   (Keystore en Android, Keychain en iPhone). Nunca en texto plano.
//
// ¿CÓMO LO CAMBIO?
//   Si algún día hay que guardar otro dato secreto (por ejemplo, un token de
//   notificaciones), agrega aquí un método nuevo con su propia clave. No lo
//   guardes en SharedPreferences: ahí cualquiera podría leerlo.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token de sesión de forma cifrada.
///
/// ¿Por qué no en SharedPreferences? Porque ahí queda en texto plano: alguien con
/// el teléfono (o con un respaldo) podría copiarlo y entrar como tú. El
/// almacenamiento seguro lo cifra con llaves que solo tiene tu teléfono.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
