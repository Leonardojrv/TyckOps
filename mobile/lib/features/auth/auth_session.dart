import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/token_storage.dart';
import '../../data/models/app_user.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/auth_repository.dart';

/// Guarda quién tiene la sesión iniciada y avisa cuando cambia.
///
/// Es un ChangeNotifier: cuando llamamos a notifyListeners(), el router se
/// entera y vuelve a evaluar a qué pantalla mandar al usuario.
class AuthSession extends ChangeNotifier {
  AuthSession(this._tokenStorage);

  final TokenStorage _tokenStorage;
  AppUser? _user;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  UserRole? get role => _user?.role;

  /// RF-02: el usuario todavía no decide si cambia o mantiene su contraseña.
  bool get needsFirstAccess => _user?.isFirstLogin ?? false;

  /// Al abrir la app: si hay un token guardado, se le pregunta al servidor
  /// quién es el usuario (GET /auth/me) para no pedir el login otra vez.
  Future<void> restore(AuthRepository repository) async {
    if (await _tokenStorage.readToken() == null) return;
    try {
      _user = await repository.currentUser().timeout(const Duration(seconds: 5));
      notifyListeners();
    } on Exception {
      // Token vencido (el ApiClient ya lo borró al recibir 401), servidor
      // caído o sin internet: se muestra el login normal.
    }
  }

  /// Se llama después de un login exitoso.
  Future<void> signIn(AppUser user, String token) async {
    await _tokenStorage.saveToken(token);
    _user = user;
    notifyListeners();
  }

  /// Actualiza los datos del usuario (por ejemplo, al terminar el primer acceso).
  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _tokenStorage.clear();
    _user = null;
    notifyListeners();
  }
}
