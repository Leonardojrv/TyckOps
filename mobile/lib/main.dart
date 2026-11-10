import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/api_config.dart';
import 'core/network/token_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/auth_session.dart';

/// Punto de entrada. Aquí se crean los objetos compartidos UNA sola vez y
/// se pasan hacia abajo (esto se llama "inyección de dependencias").
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  final session = AuthSession(tokenStorage);
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onUnauthorized: session.signOut, // token vencido → de vuelta al login
  );
  final AuthRepository authRepository =
      ApiConfig.useFakeAuth ? FakeAuthRepository() : ApiAuthRepository(apiClient);

  // Mientras se restaura la sesión, Android e iOS siguen mostrando su
  // pantalla de carga nativa (la app aún no dibuja nada).
  await session.restore(authRepository);

  runApp(TyckOpsApp(
    session: session,
    apiClient: apiClient,
    authRepository: authRepository,
  ));
}
