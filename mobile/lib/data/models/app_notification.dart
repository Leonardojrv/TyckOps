// ¿PARA QUÉ SIRVE?
//   Es un aviso de la pantalla "Notificaciones" (T11): un cambio de estado o un
//   "Nuevo comentario en tu ticket".
//
// ¿QUÉ HACE?
//   Lee lo que manda el servidor (GET /api/notificaciones). Cada aviso lleva el
//   ticket al que pertenece, para abrirlo al tocarlo.
//
// ¿CÓMO LO CAMBIO?
//   Si el servidor agrega un tipo de aviso, súmalo a NotificationType y revisa
//   el ícono y la etiqueta en notifications_screen.dart.

import 'ticket.dart';
import 'ticket_status.dart';

enum NotificationType {
  statusChange('estado'), // "Ticket #REP-0087 pasó a 'En proceso'"
  comment('comentario'); // "Nuevo comentario en tu ticket"

  const NotificationType(this.apiValue);

  final String apiValue;

  static NotificationType? fromApi(Object? value) =>
      NotificationType.values.where((t) => t.apiValue == value).firstOrNull;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.ticketId,
    required this.ticketCode,
    this.status,
    this.commentId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt; // en hora local
  final String ticketId; // para abrir el ticket al tocar el aviso
  final String ticketCode; // "REP-0087"
  final TicketStatus? status; // estado nuevo (solo en cambios de estado)
  final String? commentId; // solo en "Nuevo comentario"

  AppNotification markedRead() => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        read: true,
        createdAt: createdAt,
        ticketId: ticketId,
        ticketCode: ticketCode,
        status: status,
        commentId: commentId,
      );

  /// null si el aviso viene incompleto o con un id raro (no se muestra).
  static AppNotification? tryParse(Map<String, dynamic> json) {
    final type = NotificationType.fromApi(json['tipo']);
    final ticketId = json['ticketId']?.toString() ?? '';
    final created = DateTime.tryParse(json['creadaEn']?.toString() ?? '');
    if (type == null || created == null || !Ticket.isSafeId(ticketId)) return null;
    final rawStatus = json['estado'] as String?;
    TicketStatus? status;
    try {
      status = rawStatus == null ? null : TicketStatus.fromApi(rawStatus);
    } on FormatException {
      status = null;
    }
    return AppNotification(
      id: json['id'].toString(),
      type: type,
      title: json['titulo'] as String? ?? '',
      body: json['cuerpo'] as String? ?? '',
      read: json['leida'] == true,
      createdAt: created.toLocal(),
      ticketId: ticketId,
      ticketCode: json['codigo'] as String? ?? '',
      status: status,
      commentId: json['comentarioId']?.toString(),
    );
  }
}

/// La lista de avisos y cuántos faltan por leer.
class NotificationFeed {
  const NotificationFeed({required this.items, required this.unread});

  final List<AppNotification> items; // del más nuevo al más antiguo
  final int unread;
}
