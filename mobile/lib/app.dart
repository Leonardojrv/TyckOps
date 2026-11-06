import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/app_router.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/auth_session.dart';

/// Widget raíz: aplica el tema GA.MA y el router.
class TyckOpsApp extends StatefulWidget {
  const TyckOpsApp({
    super.key,
    required this.session,
    required this.apiClient,
    required this.authRepository,
  });

  final AuthSession session;
  final ApiClient apiClient; // lo usarán los repositorios reales desde la T3
  final AuthRepository authRepository;

  @override
  State<TyckOpsApp> createState() => _TyckOpsAppState();
}

class _TyckOpsAppState extends State<TyckOpsApp> {
  // El router se crea UNA vez. Si se creara dentro de build(), se
  // reiniciaría la navegación cada vez que la pantalla se redibuja.
  late final GoRouter _router = createRouter(widget.session, widget.authRepository);

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
