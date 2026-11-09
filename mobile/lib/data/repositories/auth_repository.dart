import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

/// Resultado de un login exitoso: el usuario y su token.
typedef LoginResult = ({AppUser user, String token});

/// "Contrato" de autenticación. Las pantallas solo conocen esta interfaz, así
/// que cambiar la versión simulada por la real no obliga a tocar ninguna.
abstract interface class AuthRepository {
  /// RF-01: POST /auth/login
  Future<LoginResult> login({required String email, required String password});

  /// Restaura la sesión al abrir la app: GET /auth/me
  Future<AppUser> currentUser();

  /// RF-02: POST /auth/primer-acceso. Sin [newPassword] mantiene la actual.
  Future<AppUser> completeFirstAccess({String? currentPassword, String? newPassword});
}

/// Versión real: habla con la API del backend (backend/src/modules/auth).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<LoginResult> login({required String email, required String password}) async {
    final data = _unwrap(await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    ));
    return (user: AppUser.fromJson(_map(data['user'])), token: data['token'] as String);
  }

  @override
  Future<AppUser> currentUser() async {
    final data = _unwrap(await _api.get<Map<String, dynamic>>('/auth/me'));
    return AppUser.fromJson(_map(data['user']));
  }

  @override
  Future<AppUser> completeFirstAccess({String? currentPassword, String? newPassword}) async {
    final changing = newPassword != null && newPassword.isNotEmpty;
    final data = _unwrap(await _api.post<Map<String, dynamic>>(
      '/auth/primer-acceso',
      body: {
        if (changing) 'currentPassword': currentPassword,
        if (changing) 'newPassword': newPassword,
      },
    ));
    return AppUser.fromJson(_map(data['user']));
  }

  /// Las respuestas vienen como {"success": true, "data": {...}}: nos quedamos con "data".
  static Map<String, dynamic> _unwrap(Map<String, dynamic>? body) => _map(body?['data']);

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
class FakeAuthRepository implements AuthRepository {
  AppUser? _current;

  @override
  Future<LoginResult> login({required String email, required String password}) async {
    await _simulateNetwork();
    if (password.length < 4) {
      // Mensaje genérico a propósito: nunca decir si falló el correo o la
      // contraseña, para no ayudar a adivinar qué cuentas existen.
      throw const ApiException('Correo o contraseña incorrectos.', statusCode: 401);
    }

    final normalized = email.trim().toLowerCase();
    final isAdmin = normalized.startsWith('admin');
    final user = AppUser(
      id: 'demo-${isAdmin ? 'admin' : 'worker'}',
      name: isAdmin ? 'Felipe Morales' : 'Camila Henríquez',
      email: normalized,
      role: isAdmin ? UserRole.admin : UserRole.worker,
      termsAccepted: true,
      isFirstLogin: !isAdmin,
    );
    _current = user;
    return (user: user, token: 'token-simulado');
  }

  @override
  Future<AppUser> currentUser() async => _current ?? (throw _expired);

  @override
  Future<AppUser> completeFirstAccess({String? currentPassword, String? newPassword}) async {
    await _simulateNetwork();
    final user = _current ?? (throw _expired);
    final changing = newPassword != null && newPassword.isNotEmpty;
    if (changing && (currentPassword ?? '').length < 4) {
      throw const ApiException('La contraseña temporal actual no es correcta.', statusCode: 400);
    }
    return _current = user.copyWith(isFirstLogin: false);
  }

  static const _expired = ApiException('Tu sesión expiró. Inicia sesión nuevamente.', statusCode: 401);

  static Future<void> _simulateNetwork() => Future<void>.delayed(const Duration(milliseconds: 900));
}
