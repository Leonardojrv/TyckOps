// ¿PARA QUÉ SIRVE?
//   Es el chip de estado del colaborador y el punto que "late".
//
// ¿QUÉ HACE?
//   Pinta cada estado con su color del mockup (gris en curso, rosado rechazado,
//   oscuro resuelto).
//
// ¿CÓMO LO CAMBIO?
//   Si quieres cambiar cómo se ve un estado, cámbialo solo aquí.

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/ticket_status.dart';
import '../worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

/// Chip con el estado del ticket, con los colores del mockup "Mis solicitudes":
/// - En curso (recibido, revisión, aprobado, en proceso): gris con punto que late.
/// - Rechazado: rosado con ícono de cancelar.
/// - Resuelto o cerrado: oscuro con check.
/// - Cancelado: gris claro.
/// Si quieres cambiar cómo se ve un estado, se cambia solo aquí.
class TicketStatusChip extends StatelessWidget {
  const TicketStatusChip({super.key, required this.status, this.large = false});

  final TicketStatus status;
  final bool large; // versión un poco más grande para el detalle

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Widget lead) = switch (status) {
      TicketStatus.rejected => (_C.errorContainer, _C.error, Icon(Symbols.cancel, size: large ? 14 : 12, color: _C.error)),
      TicketStatus.resolved || TicketStatus.closed => (
          _C.inverseSurface,
          _C.inverseOnSurface,
          Icon(Symbols.check_circle, size: large ? 14 : 12, color: _C.inverseOnSurface),
        ),
      TicketStatus.cancelled => (_C.containerHigh, _C.secondary, Icon(Symbols.block, size: large ? 14 : 12, color: _C.secondary)),
      _ => (_C.tertiaryContainer, _C.white, const PulsingDot(color: _C.white, size: 6)),
    };
    return Semantics(
      label: 'Estado: ${status.label}',
      excludeSemantics: true,
      child: Container(
        height: large ? 26 : 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            lead,
            const SizedBox(width: 6),
            Text(
              status.label,
              style: (large ? _T.labelSm(fg) : _T.caption(fg)).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto de color que "late" suavemente (animate-ping de los mockups).
/// Se usa para marcar lo que está vivo: un ticket en curso o la fase actual.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.scale(
              scale: 1 + _c.value * 1.2,
              child: Opacity(opacity: 0.75 * (1 - _c.value), child: child),
            ),
            child: dot,
          ),
          dot,
        ],
      ),
    );
  }
}
