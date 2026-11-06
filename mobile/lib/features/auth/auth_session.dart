import 'package:flutter/foundation.dart';

import '../../core/network/token_storage.dart';
import '../../data/models/app_user.dart';
import '../../data/models/user_role.dart';

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

  /// Se llama después de un login exitoso (T3).
  Future<void> signIn(AppUser user, String token) async {
    await _tokenStorage.saveToken(token);
    _user = user;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _tokenStorage.clear();
    _user = null;
    notifyListeners();
  }
}
