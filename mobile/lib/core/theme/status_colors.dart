import 'package:flutter/material.dart';

import '../../data/models/ticket_status.dart';

/// Par de colores (fondo + texto) de un chip de estado.
class StatusColors {
  const StatusColors(this.background, this.foreground);

  final Color background;
  final Color foreground;

  /// Los 8 colores del sistema del administrador (decisión del 05-11-2026).
  static StatusColors of(TicketStatus status) => switch (status) {
        TicketStatus.received => const StatusColors(Color(0xFFF0F4F8), Color(0xFF334E68)),
        TicketStatus.inReview => const StatusColors(Color(0xFFEEF2FF), Color(0xFF3730A3)),
        TicketStatus.approved => const StatusColors(Color(0xFFECFDF5), Color(0xFF065F46)),
        TicketStatus.rejected => const StatusColors(Color(0xFFFEF2F2), Color(0xFF991B1B)),
        TicketStatus.inProgress => const StatusColors(Color(0xFFEFF6FF), Color(0xFF1E40AF)),
        TicketStatus.resolved => const StatusColors(Color(0xFFF0FDFA), Color(0xFF115E59)),
        TicketStatus.closed => const StatusColors(Color(0xFFF1F5F9), Color(0xFF475569)),
        TicketStatus.cancelled => const StatusColors(Color(0xFFF4F4F4), Color(0xFF71717A)),
      };
}
