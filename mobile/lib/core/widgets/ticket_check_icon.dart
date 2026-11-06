import 'package:flutter/material.dart';

/// Ícono "ticket con check" de la pestaña Tickets del administrador.
///
/// No existe en Material Icons, así que se dibuja a mano con el mismo
/// trazo SVG del mockup (docs/mockups/administrador/inicio_del_administrador):
///   M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v3a2 2 0 0 0 0 4v3a2 2 0 0 1-2 2H6
///   a2 2 0 0 1-2-2v-3a2 2 0 0 0 0-4V6z   +   M9 12l2 2 4-4
class TicketCheckIcon extends StatelessWidget {
  const TicketCheckIcon({super.key, required this.color, this.size = 24, this.filled = false});

  final Color color;
  final double size;
  final bool filled; // pestaña activa: relleno suave del mismo color

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TicketCheckPainter(color: color, filled: filled),
    );
  }
}

class _TicketCheckPainter extends CustomPainter {
  _TicketCheckPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    // El SVG mide 24×24: se escala al tamaño pedido.
    canvas.scale(size.width / 24, size.height / 24);

    const r = Radius.circular(2);
    final ticket = Path()
      ..moveTo(4, 6)
      ..arcToPoint(const Offset(6, 4), radius: r)
      ..lineTo(18, 4)
      ..arcToPoint(const Offset(20, 6), radius: r)
      ..lineTo(20, 9)
      ..arcToPoint(const Offset(20, 13), radius: r, clockwise: false) // muesca derecha
      ..lineTo(20, 16)
      ..arcToPoint(const Offset(18, 18), radius: r)
      ..lineTo(6, 18)
      ..arcToPoint(const Offset(4, 16), radius: r)
      ..lineTo(4, 13)
      ..arcToPoint(const Offset(4, 9), radius: r, clockwise: false) // muesca izquierda
      ..close();

    final check = Path()
      ..moveTo(9, 12)
      ..lineTo(11, 14)
      ..lineTo(15, 10);

    if (filled) {
      canvas.drawPath(ticket, Paint()..color = color.withValues(alpha: 0.12));
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(ticket, stroke);
    canvas.drawPath(check, stroke);
  }

  @override
  bool shouldRepaint(_TicketCheckPainter old) => old.color != color || old.filled != filled;
}
