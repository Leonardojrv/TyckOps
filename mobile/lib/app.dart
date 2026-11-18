// ¿PARA QUÉ SIRVE?
//   Es la "caja" que envuelve toda la app.
//
// ¿QUÉ HACE?
//   Aplica los colores y letras de GA.MA (el tema) y conecta el mapa de
//   pantallas (el router).
//
// ¿CÓMO LO CAMBIO?
//   Normalmente no hay que tocarlo. Si sumas una dependencia que el router necesita,
//   agrégala como parámetro aquí y en main.dart.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/app_router.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/report_repository.dart';
import 'features/auth/auth_session.dart';
import 'features/worker/my_tickets_store.dart';

/// Widget raíz: aplica el tema GA.MA y el router.
class TyckOpsApp extends StatefulWidget {
  const TyckOpsApp({
    super.key,
    required this.session,
    required this.apiClient,
    required this.authRepository,
    required this.ticketsStore,
    required this.reportRepository,
  });

  final AuthSession session;
  final ApiClient apiClient; // lo usarán los repositorios reales desde la T3
  final AuthRepository authRepository;
  final MyTicketsStore ticketsStore;
  final ReportRepository reportRepository;

  @override
  State<TyckOpsApp> createState() => _TyckOpsAppState();
}

class _TyckOpsAppState extends State<TyckOpsApp> {
  // El mapa de pantallas se crea una sola vez. Si se creara cada vez que la
  // pantalla se vuelve a dibujar, la app volvería al inicio a cada rato.
  late final GoRouter _router = createRouter(
    widget.session,
    widget.authRepository,
    widget.ticketsStore,
    widget.reportRepository,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TyckOps',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
