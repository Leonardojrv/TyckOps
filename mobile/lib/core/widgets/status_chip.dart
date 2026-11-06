import 'package:flutter/material.dart';

import '../../data/models/ticket_status.dart';
import '../theme/app_typography.dart';
import '../theme/status_colors.dart';

/// Chip con el estado del ticket: forma de píldora, punto de color y texto.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(status);
    return Semantics(
      label: 'Estado: ${status.label}',
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: colors.foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: AppTypography.labelSmall.copyWith(color: colors.foreground),
            ),
          ],
        ),
      ),
    );
  }
}
