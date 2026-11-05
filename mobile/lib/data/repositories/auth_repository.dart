import '../../core/network/api_exception.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

/// Resultado de un login exitoso: el usuario y su token.
typedef LoginResult = ({AppUser user, String token});

/// "Contrato" del login. Las pantallas solo conocen esta interfaz, así que
/// cambiar la versión simulada por la real (con la API de Moisés) no obliga
/// a tocar ninguna pantalla.
abstract interface class AuthRepository {
  Future<LoginResult> login({required String email, required String password});
}

/// Login SIMULADO mientras no exista el endpoint del backend (T3:
/// "si no está, usar una respuesta simulada").
///
/// Regla de la simulación:
/// - Correos que empiezan con "admin" → rol Administrador.
/// - Cualquier otro correo @gamaitaly.cl → rol Colaborador.
/// - Cualquier contraseña de al menos 4 caracteres es aceptada.
class FakeAuthRepository implements AuthRepository {
  @override
  Future<LoginResult> login({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900)); // simula la red

    if (password.length < 4) {
      // Mensaje genérico a propósito: nunca decir si falló el correo o la
      // contraseña, para no ayudar a adivinar qué cuentas existen.
      throw const ApiException('Correo o contraseña incorrectos.', statusCode: 401);
    }

    final normalized = email.trim().toLowerCase();
    final isAdmin = normalized.startsWith('admin');
    return (
      user: AppUser(
        id: 'demo-${isAdmin ? 'admin' : 'worker'}',
        name: isAdmin ? 'Felipe Morales' : 'Camila Henríquez',
        email: normalized,
        role: isAdmin ? UserRole.admin : UserRole.worker,
        termsAccepted: true,
      ),
      token: 'token-simulado',
    );
  }
}
