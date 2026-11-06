import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token de sesión (JWT) de forma cifrada.
///
/// Por qué no SharedPreferences: guarda en texto plano y cualquiera con
/// acceso al teléfono (o a un respaldo) podría leer el token y entrar como
/// el usuario. flutter_secure_storage usa el Keystore de Android y el
/// Keychain de iOS, que cifran los datos con llaves del propio dispositivo.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
