import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/auth_session.dart';

/// Punto de entrada. Aquí se crean los objetos compartidos UNA sola vez y
/// se pasan hacia abajo (esto se llama "inyección de dependencias").
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  final session = AuthSession(tokenStorage);
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onUnauthorized: session.signOut, // token vencido → de vuelta al login
  );

  runApp(TyckOpsApp(
    session: session,
    apiClient: apiClient,
    // Simulado hasta que exista el endpoint de login del backend.
    authRepository: FakeAuthRepository(),
  ));
}
