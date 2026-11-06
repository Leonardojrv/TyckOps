import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/ticket_status.dart';

/// Galería de componentes (solo en modo debug).
/// Sirve para comparar cada componente con los mockups de Stitch (criterio
/// de "Hecho" de la T2).
class ComponentsGalleryScreen extends StatelessWidget {
  const ComponentsGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Componentes base')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Botones'),
          AppButton(label: 'Iniciar sesión', trailingIcon: Icons.arrow_forward, onPressed: () {}),
          const SizedBox(height: 12),
          AppButton(label: 'Nueva', variant: AppButtonVariant.secondary, onPressed: () {}),
          const SizedBox(height: 12),
          AppButton(label: 'Cancelar', variant: AppButtonVariant.outline, onPressed: () {}),
          const SizedBox(height: 12),
          const AppButton(label: 'Rechazar (deshabilitado)', onPressed: null),
          const SizedBox(height: 12),
          AppButton(label: 'Enviando', isLoading: true, onPressed: () {}),

          _section('Chips de estado'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in TicketStatus.values) StatusChip(s)],
          ),

          _section('Tarjeta de ticket'),
          AppCard(
            onTap: () {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#REP-0142 · Electricidad',
                        style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                    const Spacer(),
                    const StatusChip(TicketStatus.inProgress),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Enchufe en mal estado', style: AppTypography.headlineSmall),
                const SizedBox(height: 8),
                Text('Hoy, 10:30 hrs · Recepción central',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),

          _section('Campos de texto'),
          const AppTextField(
            label: 'Correo corporativo',
            trailingLabel: 'Chile HQ',
            hint: 'ejemplo@gamaitaly.cl',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.corporateEmail,
          ),
          const SizedBox(height: 16),
          const AppTextField(
            label: 'Contraseña',
            hint: '••••••••••••',
            prefixIcon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(title, style: AppTypography.headlineSmall),
      );
}
