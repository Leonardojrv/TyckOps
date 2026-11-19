// ¿PARA QUÉ SIRVE?
//   Es quien habla con el servidor para todo lo de la sesión.
//
// ¿QUÉ HACE?
//   Inicia sesión, pregunta "¿quién soy?" al abrir la app, completa el primer
//   acceso (contraseña y términos) y la verificación en dos pasos (código de 6
//   dígitos, T8). Trae también una versión de prueba sin servidor.
//
// ¿CÓMO LO CAMBIO?
//   Si cambia una ruta de login en el servidor, cámbiala aquí. La versión de prueba
//   (FakeAuthRepository) solo se usa con --dart-define=FAKE_AUTH=true; ahí el
//   código de verificación es siempre 123456.

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

/// Verificación en dos pasos pendiente (T8): a qué correo se envió el código,
/// hasta cuándo sirve y el "pase" para enviarlo.
///
/// El pase (mfaToken) vive solo en memoria mientras dura la verificación: no
/// se guarda en el teléfono y no abre ninguna otra parte de la app.
class MfaChallenge {
  const MfaChallenge({
    required this.email,
    required this.mfaToken,
    required this.expiresAt,
    required this.resendAt,
    this.role,
  });

  final String email;
  final String mfaToken;
  final DateTime expiresAt; // cuándo vence el código actual
  final DateTime resendAt; // desde cuándo el servidor acepta pedir otro
  final UserRole? role; // para mostrar "Sesión de Colaborador en curso"

  MfaChallenge copyWith({DateTime? expiresAt, DateTime? resendAt}) => MfaChallenge(
        email: email,
        mfaToken: mfaToken,
        expiresAt: expiresAt ?? this.expiresAt,
        resendAt: resendAt ?? this.resendAt,
        role: role,
      );
}

/// Lo que responde el login. Puede ser una de dos cosas:
/// - Una sesión ([user] y [token]): completa, o limitada al primer acceso.
/// - Una verificación en dos pasos pendiente ([mfa]): falta el código.
class LoginResult {
  const LoginResult.session(AppUser this._user, String this._token) : mfa = null;

  const LoginResult.mfa(MfaChallenge this.mfa)
      : _user = null,
        _token = null;

  final AppUser? _user;
  final String? _token;
  final MfaChallenge? mfa;

  bool get needsMfa => mfa != null;

  /// El usuario de la sesión. Si todavía falta el código, no hay usuario.
  AppUser get user => _user ?? (throw StateError('Falta la verificación en dos pasos'));

  /// La llave de la sesión. Si todavía falta el código, no hay llave.
  String get token => _token ?? (throw StateError('Falta la verificación en dos pasos'));
}

/// "Contrato" de autenticación. Las pantallas solo conocen esta interfaz, así
/// que cambiar la versión simulada por la real no obliga a tocar ninguna.
abstract interface class AuthRepository {
  /// RF-01: POST /auth/login
  Future<LoginResult> login({required String email, required String password});

  /// Restaura la sesión al abrir la app: GET /auth/me
  Future<AppUser> currentUser();

  /// RF-02: POST /auth/primer-acceso. Sin [newPassword] mantiene la actual.
  Future<AppUser> completeFirstAccess({
    String? currentPassword,
    String? newPassword,
    required String termsVersion,
  });

  /// T8: revisa el código de 6 dígitos. Si es correcto, entrega la sesión completa.
  Future<({AppUser user, String token})> verifyMfa(MfaChallenge challenge, String code);

  /// T8: pide un código nuevo (el anterior deja de servir).
  Future<MfaChallenge> resendMfa(MfaChallenge challenge);
}

/// Versión real: habla con la API del backend (backend/src/modules/auth).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final data = _unwrap(
      await _api.post<Map<String, dynamic>>(
        '/auth/login',
        body: {'email': email.trim().toLowerCase(), 'password': password},
      ),
    );
    // T8: el servidor pide el código antes de entregar la sesión.
    if (data['step'] == 'MFA') {
      return LoginResult.mfa(MfaChallenge(
        email: data['email'] as String? ?? email.trim().toLowerCase(),
        mfaToken: data['mfaToken'] as String,
        expiresAt: _date(data['expiraEn']),
        resendAt: _date(data['reenviarDesde']),
        role: data['role'] is String ? UserRole.fromApi(data['role'] as String) : null,
      ));
    }
    return LoginResult.session(AppUser.fromJson(_map(data['user'])), data['token'] as String);
  }

  @override
  Future<AppUser> currentUser() async {
    final data = _unwrap(await _api.get<Map<String, dynamic>>('/auth/me'));
    return AppUser.fromJson(_map(data['user']));
  }

  @override
  Future<AppUser> completeFirstAccess({
    String? currentPassword,
    String? newPassword,
    required String termsVersion,
  }) async {
    final changing = newPassword != null && newPassword.isNotEmpty;
    final data = _unwrap(
      await _api.post<Map<String, dynamic>>(
        '/auth/primer-acceso',
        body: {
          // RF-03: el servidor guarda quién aceptó y qué versión.
          'acceptTerms': true,
          'termsVersion': termsVersion,
          if (changing) 'currentPassword': currentPassword,
          if (changing) 'newPassword': newPassword,
        },
      ),
    );
    return AppUser.fromJson(_map(data['user']));
  }

  @override
  Future<({AppUser user, String token})> verifyMfa(MfaChallenge challenge, String code) async {
    final data = _unwrap(await _api.post<Map<String, dynamic>>(
      '/auth/mfa/verificar',
      body: {'codigo': code},
      bearer: challenge.mfaToken, // el pase de verificación, solo para este pedido
    ));
    return (user: AppUser.fromJson(_map(data['user'])), token: data['token'] as String);
  }

  @override
  Future<MfaChallenge> resendMfa(MfaChallenge challenge) async {
    final data = _unwrap(await _api.post<Map<String, dynamic>>(
      '/auth/mfa/reenviar',
      bearer: challenge.mfaToken,
    ));
    return challenge.copyWith(expiresAt: _date(data['expiraEn']), resendAt: _date(data['reenviarDesde']));
  }

  static DateTime _date(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : DateTime.now().add(const Duration(minutes: 3));

  /// Las respuestas vienen como {"success": true, "data": {...}}: nos quedamos con "data".
  static Map<String, dynamic> _unwrap(Map<String, dynamic>? body) =>
      _map(body?['data']);

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    throw const ApiException('Respuesta inesperada del servidor.');
  }
}

/// Versión SIMULADA, para trabajar sin backend (--dart-define=FAKE_AUTH=true).
///
/// Regla de la simulación:
/// - Correos que empiezan con "admin" → rol Administrador.
/// - Cualquier otro correo @gamaitaly.cl → rol Colaborador, en primer acceso.
/// - Cualquier contraseña de al menos 4 caracteres es aceptada.
/// - Después del primer acceso, el login pide el código: siempre 123456
///   (código fijo SOLO para desarrollo, como pide la T8).
class FakeAuthRepository implements AuthRepository {
  AppUser? _current;
  final _alreadyConfigured = <String>{}; // correos que ya hicieron el primer acceso
  static const devCode = '123456';
  int _wrongTries = 0;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    await _simulateNetwork();
    if (password.length < 4) {
      // Mensaje genérico a propósito: nunca decir si falló el correo o la
      // contraseña, para no ayudar a adivinar qué cuentas existen.
      throw const ApiException(
        'Correo o contraseña incorrectos.',
        statusCode: 401,
      );
    }

    final normalized = email.trim().toLowerCase();
    final isAdmin = normalized.startsWith('admin');
    final firstTime = !isAdmin && !_alreadyConfigured.contains(normalized);
    final user = AppUser(
      id: 'demo-${isAdmin ? 'admin' : 'worker'}',
      // Nombres neutros: no inventamos personas en los datos de prueba.
      name: isAdmin ? 'Administrador GA.MA' : 'Colaborador GA.MA',
      email: normalized,
      role: isAdmin ? UserRole.admin : UserRole.worker,
      termsAccepted: !firstTime,
      isFirstLogin: firstTime,
    );
    _current = user;
    if (firstTime) return LoginResult.session(user, 'token-simulado-primer-acceso');

    // Ya configurado: primero el código.
    _wrongTries = 0;
    final now = DateTime.now();
    return LoginResult.mfa(MfaChallenge(
      email: normalized,
      mfaToken: 'pase-simulado',
      expiresAt: now.add(const Duration(minutes: 3)),
      resendAt: now.add(const Duration(seconds: 30)),
      role: user.role,
    ));
  }

  @override
  Future<AppUser> currentUser() async => _current ?? (throw _expired);

  @override
  Future<AppUser> completeFirstAccess({
    String? currentPassword,
    String? newPassword,
    required String termsVersion,
  }) async {
    await _simulateNetwork();
    final user = _current ?? (throw _expired);
    final changing = newPassword != null && newPassword.isNotEmpty;
    if (changing && (currentPassword ?? '').length < 4) {
      throw const ApiException(
        'La contraseña temporal actual no es correcta.',
        statusCode: 400,
      );
    }
    _alreadyConfigured.add(user.email);
    return _current = user.copyWith(isFirstLogin: false, termsAccepted: true);
  }

  @override
  Future<({AppUser user, String token})> verifyMfa(MfaChallenge challenge, String code) async {
    await _simulateNetwork();
    if (DateTime.now().isAfter(challenge.expiresAt)) {
      throw const ApiException('El código venció. Pide uno nuevo con "Reenviar código".', statusCode: 400, code: 'MFA_CODIGO_VENCIDO');
    }
    if (code != devCode) {
      _wrongTries++;
      if (_wrongTries >= 5) {
        throw const ApiException('Demasiados intentos. Inicia sesión de nuevo para recibir otro código.', statusCode: 429, code: 'MFA_DEMASIADOS_INTENTOS');
      }
      throw ApiException('Código incorrecto. Te quedan ${5 - _wrongTries} intentos.', statusCode: 400, code: 'MFA_CODIGO_INCORRECTO');
    }
    final user = _current ?? (throw _expired);
    return (user: user, token: 'token-simulado');
  }

  @override
  Future<MfaChallenge> resendMfa(MfaChallenge challenge) async {
    await _simulateNetwork();
    _wrongTries = 0;
    final now = DateTime.now();
    return challenge.copyWith(expiresAt: now.add(const Duration(minutes: 3)), resendAt: now.add(const Duration(seconds: 30)));
  }

  static const _expired = ApiException(
    'Tu sesión expiró. Inicia sesión nuevamente.',
    statusCode: 401,
  );

  static Future<void> _simulateNetwork() =>
      Future<void>.delayed(const Duration(milliseconds: 900));
}
