// ¿PARA QUÉ SIRVE?
//   Reúne las reglas de "Mis solicitudes" y del detalle que no dependen del diseño.
//
// ¿QUÉ HACE?
//   Decide qué tickets entran en cada filtro, busca por palabras y arma las fases de
//   la línea de tiempo.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias un filtro o una fase, hazlo aquí y corre test/tickets_test.dart.

import '../../../data/models/ticket.dart';
import '../../../data/models/ticket_detail.dart';
import '../../../data/models/ticket_status.dart';

// Reglas de "Mis solicitudes" y del detalle que no dependen de la pantalla.
// Están separadas para poder probarlas (test/tickets_test.dart) y para que,
// si cambian los filtros o las fases, se cambien en un solo lugar.

/// Los botones de filtro de "Mis solicitudes".
enum TicketFilter {
  all('Todos'),
  active('En curso'), // recibido, en revisión, aprobado o en proceso
  rejected('Rechazado'),
  resolved('Resuelto'); // resuelto o cerrado

  const TicketFilter(this.label);

  final String label;

  bool matches(Ticket t) => switch (this) {
        TicketFilter.all => true,
        TicketFilter.active => t.isActive,
        TicketFilter.rejected => t.status == TicketStatus.rejected,
        TicketFilter.resolved => t.status == TicketStatus.resolved || t.status == TicketStatus.closed,
      };
}

/// Quita tildes y mayúsculas para que "baño" encuentre "Baños".
String _plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u');

/// Aplica el filtro y la búsqueda (por código, ubicación, título o categoría).
///
/// Cada palabra que escribas debe aparecer en algún lado del ticket, en
/// cualquier orden: "sala b" encuentra "Sala de reuniones B".
List<Ticket> filterTickets(List<Ticket> tickets, TicketFilter filter, String query) {
  final words = _plain(query.replaceAll('#', ' ')).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  bool hits(Ticket t) {
    if (words.isEmpty) return true;
    final text = _plain([t.code, t.location, t.title, t.category].join(' '));
    return words.every(text.contains);
  }

  return [
    for (final t in tickets)
      if (filter.matches(t) && hits(t)) t,
  ];
}

/// Estado de cada paso en la línea de tiempo.
enum PhaseState { done, current, pending }

/// Un paso de la línea de tiempo del detalle.
class TimelineStep {
  const TimelineStep({required this.status, required this.state, required this.description, this.date});

  final TicketStatus status;
  final PhaseState state;
  final String description;
  final DateTime? date; // solo la mostramos cuando la sabemos de verdad
}

// Lo que significa cada fase, en palabras simples para el colaborador.
const _descriptions = {
  TicketStatus.received: 'Ticket registrado en la plataforma de Servicios Generales.',
  TicketStatus.inReview: 'Evaluación técnica preliminar de la falla reportada.',
  TicketStatus.approved: 'Servicios Generales aprobó la reparación.',
  TicketStatus.inProgress: 'El equipo técnico está trabajando en la reparación.',
  TicketStatus.resolved: 'Reparación terminada y lista para tu conformidad.',
  TicketStatus.closed: 'Cierre administrativo de la solicitud.',
  TicketStatus.rejected: 'La solicitud no pudo ser atendida. Revisa el motivo más arriba.',
  TicketStatus.cancelled: 'Cancelaste esta solicitud.',
  TicketStatus.selfHelp: 'Estás siguiendo una guía de autoayuda.',
};

/// El camino normal de un ticket: 6 fases (mockup "Trazabilidad del Servicio").
const normalFlow = [
  TicketStatus.received,
  TicketStatus.inReview,
  TicketStatus.approved,
  TicketStatus.inProgress,
  TicketStatus.resolved,
  TicketStatus.closed,
];

/// Arma la línea de tiempo según el estado actual del ticket.
///
/// - Camino normal: las fases anteriores quedan hechas, la actual se marca y
///   las siguientes quedan pendientes.
/// - Rechazado: Recibido → En revisión → Rechazado (mockup del rechazo).
/// - Cancelado: Recibido → Cancelado.
/// - Autogestión (T10): Recibido → Autogestión.
/// - Cerrado con la guía de IA (T10): Recibido → Autogestión → Cerrado.
///
/// Cuando el detalle incluye historial persistido, cada cambio se muestra en
/// orden y el estado actual queda resaltado.
List<TimelineStep> buildTimeline(
  TicketStatus status, {
  required DateTime createdAt,
  DateTime? closedAt,
  bool closedBySelfHelp = false,
  List<TicketTimelineEntry> history = const [],
}) {
  TimelineStep step(TicketStatus s, PhaseState state, [DateTime? date]) =>
      TimelineStep(status: s, state: state, description: _descriptions[s]!, date: date);

  if (history.isNotEmpty) {
    return [
      for (final event in history)
        TimelineStep(
          status: event.status,
          state: event.current ? PhaseState.current : PhaseState.done,
          description: event.previousStatus == null
              ? _descriptions[event.status]!
              : 'Cambio de ${event.previousStatus!.label} a ${event.status.label}.',
          date: event.date,
        ),
    ];
  }

  // T10: lo cerró el colaborador con la guía; nunca pasó por revisión ni reparación.
  if (status == TicketStatus.closed && closedBySelfHelp) {
    return [
      step(TicketStatus.received, PhaseState.done, createdAt),
      step(TicketStatus.selfHelp, PhaseState.done),
      TimelineStep(
        status: TicketStatus.closed,
        state: PhaseState.current,
        description: 'Lo solucionaste siguiendo la guía de IA.',
        date: closedAt,
      ),
    ];
  }

  if (status == TicketStatus.selfHelp) {
    return [
      step(TicketStatus.received, PhaseState.done, createdAt),
      step(TicketStatus.selfHelp, PhaseState.current),
    ];
  }

  if (status == TicketStatus.rejected) {
    return [
      step(TicketStatus.received, PhaseState.done, createdAt),
      step(TicketStatus.inReview, PhaseState.done),
      step(TicketStatus.rejected, PhaseState.current, closedAt),
    ];
  }
  if (status == TicketStatus.cancelled) {
    return [
      step(TicketStatus.received, PhaseState.done, createdAt),
      step(TicketStatus.cancelled, PhaseState.current, closedAt),
    ];
  }
  final current = normalFlow.indexOf(status);
  return [
    for (var i = 0; i < normalFlow.length; i++)
      step(
        normalFlow[i],
        i < current ? PhaseState.done : (i == current ? PhaseState.current : PhaseState.pending),
        i == 0 ? createdAt : (i == current && i >= 4 ? closedAt : null),
      ),
  ];
}
