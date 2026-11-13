import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';

/// Pantalla temporal para las secciones que aún no se construyen.
/// Cada una dice en qué tarea se hará. Se irán reemplazando de T3 a T15.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.task,
    this.onSignOut,
    this.onBack,
  });

  final String title;
  final String task;
  final VoidCallback? onSignOut;
  final VoidCallback? onBack; // muestra una flecha para volver

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Volver',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              Text(
                'SERVICIOS GENERALES',
                style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
              ),
              Text(title, style: AppTypography.headlineMedium),
              const Spacer(),
              Center(
                child: Text(
                  'Pantalla en construcción\nSe desarrolla en la $task',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              if (onSignOut != null)
                AppButton(
                  label: 'Cerrar sesión',
                  variant: AppButtonVariant.outline,
                  leadingIcon: Icons.logout,
                  onPressed: onSignOut,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
