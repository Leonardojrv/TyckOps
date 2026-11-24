// ¿PARA QUÉ SIRVE?
//   Es todo lo que muestra la pantalla "Detalle del ticket" (T7).
//
// ¿QUÉ HACE?
//   Junta el ticket, su descripción, si tiene foto, el motivo de rechazo y los
//   comentarios del administrador.
//
// ¿CÓMO LO CAMBIO?
//   Si el detalle suma un dato nuevo (por ejemplo, el técnico asignado), agrégalo
//   aquí y en fromJson.

import 'self_help.dart';
import 'ticket.dart';
import 'ticket_status.dart';

/// Un comentario del administrador sobre un ticket (T7).
/// El colaborador solo lo lee: no hay respuestas ni chat.
class TicketComment {
  const TicketComment({required this.id, required this.author, required this.createdAt, required this.text});

  final String id;
  final String author; // nombre visible (nunca el correo)
  final DateTime createdAt; // en hora local
  final String text;

  factory TicketComment.fromJson(Map<String, dynamic> json) => TicketComment(
        id: json['id'].toString(),
        author: (json['author'] as String?)?.trim().isNotEmpty == true ? json['author'] as String : 'Servicios Generales',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        text: json['text'] as String? ?? '',
      );
}

/// Todo lo que muestra la pantalla "Detalle del ticket".
///
/// Viene de GET /api/tickets/:id. Si el backend agrega un dato nuevo al
/// detalle, se suma aquí y en [TicketDetail.fromJson].
class TicketDetail {
  const TicketDetail({
    required this.ticket,
    required this.description,
    required this.hasPhoto,
    required this.comments,
    this.rejectionReason,
    this.closedAt,
    this.selfHelp = false,
    this.closedBySelfHelp = false,
    this.duplicateOf,
  });

  final Ticket ticket; // código, estado, categoría, ubicación, fecha...
  final String description; // lo que escribió el colaborador al reportar
  final bool hasPhoto; // si adjuntó foto (la foto se descarga aparte, solo si se pide)
  final List<TicketComment> comments; // del más antiguo al más nuevo
  final String? rejectionReason; // solo llega en tickets rechazados (RF-07)
  final DateTime? closedAt; // cuándo se cerró, rechazó o canceló
  final bool selfHelp; // T10: prioridad Baja y Recibido → se muestra la guía de autoayuda
  final bool closedBySelfHelp; // T10: lo cerraste tú con la guía (sin pasar por administración)
  final DuplicateOriginal? duplicateOf; // T10: si tu ticket fue agrupado con otro

  /// Seguridad extra: aunque el servidor ya lo filtra, el motivo solo se
  /// muestra si el ticket está rechazado.
  String? get visibleRejectionReason =>
      ticket.status == TicketStatus.rejected && (rejectionReason?.trim().isNotEmpty ?? false) ? rejectionReason!.trim() : null;

  factory TicketDetail.fromJson(Map<String, dynamic> json) {
    final comments = [
      for (final item in (json['comments'] as List?) ?? const [])
        TicketComment.fromJson((item as Map).cast<String, dynamic>()),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final closed = json['closedAt'] as String?;
    return TicketDetail(
      ticket: Ticket.fromJson(json),
      description: (json['description'] as String?) ?? (json['title'] as String? ?? ''),
      hasPhoto: json['hasPhoto'] == true,
      comments: comments,
      rejectionReason: json['rejectionReason'] as String?,
      closedAt: closed == null ? null : DateTime.parse(closed).toLocal(),
      selfHelp: json['selfHelp'] == true,
      closedBySelfHelp: json['closedBySelfHelp'] == true,
      duplicateOf: json['duplicateOf'] is Map
          ? DuplicateOriginal.fromJson((json['duplicateOf'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}
