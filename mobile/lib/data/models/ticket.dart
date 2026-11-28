// ¿PARA QUÉ SIRVE?
//   Representa un ticket tal como lo ve su dueño.
//
// ¿QUÉ HACE?
//   Guarda código, categoría, título, estado, prioridad, ubicación y fecha, y valida
//   que el id sea seguro para ponerlo en una dirección.
//
// ¿CÓMO LO CAMBIO?
//   Si el servidor agrega un dato a la lista de tickets, súmalo aquí y en fromJson.

import 'ticket_status.dart';

/// Prioridad que asigna el sistema (la IA solo usa Media y Alta; la baja
/// corresponde a los incidentes con guía de autoayuda).
enum TicketPriority {
  high('ALTA'),
  medium('MEDIA'),
  low('BAJA');

  const TicketPriority(this.apiValue);

  final String apiValue;

  /// null = todavía sin prioridad (ticket recién creado). Si el servidor manda
  /// algo nuevo, no se cae la app: se trata como baja.
  static TicketPriority? fromApi(Object? value) => value == null
      ? null
      : TicketPriority.values.firstWhere(
          (p) => p.apiValue == value.toString().toUpperCase(),
          orElse: () => TicketPriority.low,
        );
}

/// Ticket tal como lo ve el colaborador dueño (GET /api/tickets/mis-tickets).
class Ticket {
  const Ticket({
    required this.id,
    required this.code,
    required this.category,
    required this.title,
    required this.status,
    required this.priority,
    required this.location,
    required this.createdAt,
    this.closedAt,
  });

  final String id; // id interno: solo se usa para pedir el detalle
  final String code; // número visible, ej. "REP-0142"
  final String category;
  final String title;
  final TicketStatus status;
  final TicketPriority? priority; // null = por asignar
  final String location;
  final DateTime createdAt; // siempre en hora local
  final DateTime? closedAt; // cuándo terminó (resuelto, cerrado, rechazado o cancelado)

  /// Sigue en atención (RF-05): aún no está resuelto, cerrado, rechazado ni cancelado.
  bool get isActive => status.isActiveStatus;

  /// T9 · Copia del ticket con otro estado (por ejemplo, después de cancelarlo).
  Ticket copyWith({TicketStatus? status, TicketPriority? priority, DateTime? closedAt}) => Ticket(
        id: id,
        code: code,
        category: category,
        title: title,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        location: location,
        createdAt: createdAt,
        closedAt: closedAt ?? this.closedAt,
      );

  /// Seguridad: el id viaja en la URL del detalle, así que solo se aceptan
  /// letras, números y guiones (nada de "/", "?" o "..").
  static final _safeId = RegExp(r'^[A-Za-z0-9-]{1,40}$');

  static bool isSafeId(String id) => _safeId.hasMatch(id);

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final id = json['id'].toString();
    if (!isSafeId(id)) throw FormatException('Id de ticket inválido: $id');
    return Ticket(
      id: id,
      code: json['code'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      status: TicketStatus.fromApi(json['status'] as String),
      priority: TicketPriority.fromApi(json['priority']),
      location: json['location'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      closedAt: json['closedAt'] == null ? null : DateTime.parse(json['closedAt'] as String).toLocal(),
    );
  }
}

/// Respuesta completa de "mis tickets": la lista y el resumen del home.
class MyTickets {
  const MyTickets({
    required this.tickets,
    required this.total,
    required this.inAttention,
    this.slaPercent,
  });

  final List<Ticket> tickets; // del más reciente al más antiguo
  final int total;
  final int inAttention; // tickets activos
  final double? slaPercent; // null mientras el backend no lo calcule

  List<Ticket> get active => tickets.where((t) => t.isActive).toList(growable: false);

  factory MyTickets.fromJson(Map<String, dynamic> json) {
    final resumen = (json['resumen'] as Map).cast<String, dynamic>();
    return MyTickets(
      tickets: [
        for (final item in json['tickets'] as List) Ticket.fromJson((item as Map).cast<String, dynamic>()),
      ],
      total: resumen['total'] as int,
      inAttention: resumen['enAtencion'] as int,
      slaPercent: (resumen['slaCumplido'] as num?)?.toDouble(),
    );
  }
}
