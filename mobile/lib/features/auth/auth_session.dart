// ¿PARA QUÉ SIRVE?
//   Recuerda quién inició sesión mientras la app está abierta.
//
// ¿QUÉ HACE?
//   Guarda el usuario actual, avisa a la app cuando entra o sale alguien (así el
//   router cambia de pantalla) y borra el token al cerrar sesión.
//
// ¿CÓMO LO CAMBIO?
//   Si necesitas saber algo más de la sesión en varias pantallas, agrégalo aquí.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/token_storage.dart';
import '../../data/models/app_user.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/auth_repository.dart';

/// Guarda quién tiene la sesión iniciada y avisa cuando cambia.
///
/// Cada vez que cambia la sesión, "avisa" a la app. Así el mapa de pantallas
/// se entera y vuelve a decidir a dónde mandar a la persona.
class AuthSession extends ChangeNotifier {
  AuthSession(this._tokenStorage);

  final TokenStorage _tokenStorage;
  AppUser? _user;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  UserRole? get role => _user?.role;

  /// RF-02 y RF-03: falta decidir la contraseña o aceptar los términos.
  /// Mientras sea true, el router solo deja ver la pantalla de primer acceso.
  bool get needsFirstAccess {
    final user = _user;
    return user != null && (user.isFirstLogin || !user.termsAccepted);
  }

  /// Al abrir la app: si hay un token guardado, se le pregunta al servidor
  /// quién es el usuario (GET /auth/me) para no pedir el login otra vez.
  Future<void> restore(AuthRepository repository) async {
    if (await _tokenStorage.readToken() == null) return;
    try {
      _user = await repository.currentUser().timeout(
        const Duration(seconds: 5),
      );
      notifyListeners();
    } on Exception {
      // La sesión venció (ya se borró), el servidor no responde o no hay
      // internet: en cualquiera de esos casos se muestra el login normal.
    }
  }

  // ===== Verificación en dos pasos (T8) =====

  /// La verificación pendiente, si la hay. Vive SOLO en memoria: si cierras la
  /// app a mitad de camino, tendrás que iniciar sesión de nuevo (más seguro).
  MfaChallenge? _mfa;

  MfaChallenge? get mfaChallenge => _mfa;

  /// true mientras falta escribir el código: el router solo deja ver esa pantalla.
  bool get mfaPending => _mfa != null && _user == null;

  /// El login pidió el código: se guarda la verificación y la app va a esa pantalla.
  void startMfa(MfaChallenge challenge) {
    _mfa = challenge;
    notifyListeners();
  }

  /// Se pidió un código nuevo: se actualizan los tiempos.
  void updateMfa(MfaChallenge challenge) {
    if (_mfa == null) return;
    _mfa = challenge;
    notifyListeners();
  }

  /// "Cancelar y volver al inicio de sesión" (o si el servidor bloqueó la verificación).
  void cancelMfa({String? notice}) {
    _mfa = null;
    _notice = notice;
    notifyListeners();
  }

  /// Se llama después de un login exitoso (o de verificar el código).
  Future<void> signIn(AppUser user, String token) async {
    await _tokenStorage.saveToken(token);
    _user = user;
    _mfa = null; // la verificación ya terminó
    notifyListeners();
  }

  /// Actualiza los datos del usuario (por ejemplo, al terminar el primer acceso).
  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  /// Mensaje para mostrar en el login tras cerrar sesión (ej. términos rechazados).
  String? _notice;

  String? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  Future<void> signOut({String? notice}) async {
    await _tokenStorage.clear();
    _user = null;
    _mfa = null;
    _notice = notice;
    notifyListeners();
  }
}
