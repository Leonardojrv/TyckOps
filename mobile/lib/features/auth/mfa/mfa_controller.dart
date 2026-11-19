// ¿PARA QUÉ SIRVE?
//   Es el "cerebro" de la verificación en dos pasos, separado del diseño. Así la
//   misma lógica sirve para el colaborador (T8) y el administrador (T12).
//
// ¿QUÉ HACE?
//   Lleva la cuenta regresiva del código, decide cuándo se puede reenviar,
//   envía el código al servidor y traduce sus respuestas: correcto (entra a la
//   app), incorrecto, vencido o demasiados intentos (vuelve al login).
//
// ¿CÓMO LO CAMBIO?
//   Si cambia lo que pasa ante un error del servidor, se cambia en verify().
//   Los textos de error vienen del servidor; aquí solo se decide qué hacer.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/repositories/auth_repository.dart';
import '../auth_session.dart';
import 'mfa_logic.dart';

class MfaController extends ChangeNotifier {
  MfaController({required this.session, required this.repository, DateTime Function()? now})
      : _now = now ?? DateTime.now {
    // Reloj de un segundo para la cuenta regresiva "El código expira en 02:59".
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
  }

  final AuthSession session;
  final AuthRepository repository;
  final DateTime Function() _now;
  late final Timer _ticker;

  bool _verifying = false;
  bool _resending = false;
  String? _error; // mensaje bajo las casillas
  bool _codeRejected = false; // pinta las casillas en rojo
  String? _info; // mensaje informativo (ej. "Te enviamos un código nuevo")

  bool get verifying => _verifying;
  bool get resending => _resending;
  String? get error => _error;
  String? get info => _info;
  bool get codeRejected => _codeRejected;

  MfaChallenge? get challenge => session.mfaChallenge;

  Duration get remaining {
    final c = challenge;
    if (c == null) return Duration.zero;
    final left = c.expiresAt.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get expired => remaining == Duration.zero;

  String get countdown => formatCountdown(remaining);

  /// Como dice el mockup: se puede pedir otro código al terminar el tiempo
  /// (y siempre respetando la espera mínima que pone el servidor).
  bool get canResend {
    final c = challenge;
    if (c == null || _resending || _verifying) return false;
    return expired && !_now().isBefore(c.resendAt);
  }

  /// Envía el código. Devuelve true si se pudo entrar.
  Future<bool> verify(String code) async {
    final c = challenge;
    if (c == null || _verifying) return false;
    if (code.length != mfaCodeLength) {
      _setError('Escribe los $mfaCodeLength dígitos del código.');
      return false;
    }
    if (expired) {
      _setError('El código venció. Pide uno nuevo con "Reenviar código".');
      return false;
    }
    _verifying = true;
    _error = null;
    _info = null;
    notifyListeners();
    try {
      final result = await repository.verifyMfa(c, code);
      // Correcto: se guarda la sesión completa y el router lleva al inicio.
      await session.signIn(result.user, result.token);
      return true;
    } on ApiException catch (e) {
      switch (e.code) {
        // Ya no se puede seguir con este pase: hay que iniciar sesión otra vez.
        case 'MFA_DEMASIADOS_INTENTOS' || 'MFA_SESION_INVALIDA' || 'TOKEN_INVALIDO' || 'NO_AUTENTICADO':
          session.cancelMfa(notice: e.message);
        default:
          _setError(e.message, rejected: e.code == 'MFA_CODIGO_INCORRECTO' || e.code == 'MFA_CODIGO_VENCIDO');
      }
      return false;
    } finally {
      _verifying = false;
      _notify();
    }
  }

  /// "Reenviar código": pide uno nuevo; el anterior deja de servir.
  Future<void> resend() async {
    final c = challenge;
    if (c == null || !canResend) return;
    _resending = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await repository.resendMfa(c);
      session.updateMfa(updated);
      _codeRejected = false;
      _info = 'Te enviamos un código nuevo a ${c.email}.';
    } on ApiException catch (e) {
      if (e.code == 'MFA_DEMASIADOS_INTENTOS' || e.code == 'MFA_SESION_INVALIDA') {
        session.cancelMfa(notice: e.message);
      } else {
        _error = e.message;
      }
    } finally {
      _resending = false;
      _notify();
    }
  }

  /// "Cancelar y volver al inicio de sesión".
  void cancel() => session.cancelMfa();

  /// Al escribir de nuevo se limpia el aviso rojo.
  void clearError() {
    if (_error == null && !_codeRejected) return;
    _error = null;
    _codeRejected = false;
    notifyListeners();
  }

  void _setError(String message, {bool rejected = false}) {
    _error = message;
    _info = null;
    _codeRejected = rejected;
    notifyListeners();
  }

  // La pantalla puede cerrarse justo al entrar a la app (al verificar bien):
  // después de eso ya no hay a quién avisar.
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.cancel();
    super.dispose();
  }
}
