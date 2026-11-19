// ¿PARA QUÉ SIRVE?
//   Es el punto de partida: lo primero que corre cuando abres TyckOps.
//
// ¿QUÉ HACE?
//   Crea una sola vez las piezas que toda la app comparte (la sesión, el cliente
//   que habla con el servidor y los repositorios), intenta recuperar la sesión
//   guardada y recién ahí dibuja la app.
//
// ¿CÓMO LO CAMBIO?
//   Si agregas un repositorio nuevo (por ejemplo, notificaciones en la T10), créalo
//   aquí y pásalo hacia abajo. Para probar sin servidor se usa
//   --dart-define=FAKE_AUTH=true, que elige las versiones de prueba.

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/api_config.dart';
import 'core/network/token_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/report_repository.dart';
import 'data/repositories/ticket_repository.dart';
import 'features/auth/auth_session.dart';
import 'features/worker/my_tickets_store.dart';

/// Punto de entrada. Aquí se crean los objetos compartidos UNA sola vez y
/// se pasan hacia abajo (esto se llama "inyección de dependencias").
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.validarCifrado(); // release solo con https

  final tokenStorage = TokenStorage();
  final session = AuthSession(tokenStorage);
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onUnauthorized: session.signOut, // token vencido → de vuelta al login
  );
  final AuthRepository authRepository =
      ApiConfig.useFakeAuth ? FakeAuthRepository() : ApiAuthRepository(apiClient);

  final TicketRepository ticketRepository =
      ApiConfig.useFakeAuth ? FakeTicketRepository() : ApiTicketRepository(apiClient);
  final ticketsStore = MyTicketsStore(ticketRepository, session);
  final ReportRepository reportRepository =
      ApiConfig.useFakeAuth ? FakeReportRepository() : ApiReportRepository(apiClient);

  // Mientras se restaura la sesión, Android e iOS siguen mostrando su
  // pantalla de carga nativa (la app aún no dibuja nada).
  await session.restore(authRepository);

  runApp(TyckOpsApp(
    session: session,
    apiClient: apiClient,
    authRepository: authRepository,
    ticketsStore: ticketsStore,
    reportRepository: reportRepository,
  ));
}
