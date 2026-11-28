// Pruebas de la T7 (Mis solicitudes y detalle). Revisan lo que pide el
// criterio de la tarjeta: la línea de tiempo marca el estado actual, el
// motivo solo aparece en rechazados y los comentarios llegan ordenados.
import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/data/models/ticket.dart';
import 'package:tyckops/data/models/ticket_detail.dart';
import 'package:tyckops/data/models/ticket_status.dart';
import 'package:tyckops/features/worker/tickets/ticket_logic.dart';

Ticket _t(String id, TicketStatus status, {String title = 'Falla', String location = 'Piso 2', String category = 'Baños'}) => Ticket(
      id: id,
      code: 'REP-$id',
      category: category,
      title: title,
      status: status,
      priority: null,
      location: location,
      createdAt: DateTime(2026, 11, 10),
    );

void main() {
  group('Filtros y búsqueda de "Mis solicitudes"', () {
    final tickets = [
      _t('0001', TicketStatus.inProgress, title: 'Enchufe quemado', category: 'Eléctrica'),
      _t('0002', TicketStatus.received),
      _t('0003', TicketStatus.rejected),
      _t('0004', TicketStatus.resolved),
      _t('0005', TicketStatus.closed, location: 'Sala de reuniones B'),
      _t('0006', TicketStatus.cancelled),
    ];

    test('cada filtro muestra los estados que corresponden', () {
      expect(filterTickets(tickets, TicketFilter.all, '').length, 6);
      expect(filterTickets(tickets, TicketFilter.active, '').map((t) => t.id), ['0001', '0002']);
      expect(filterTickets(tickets, TicketFilter.rejected, '').map((t) => t.id), ['0003']);
      expect(filterTickets(tickets, TicketFilter.resolved, '').map((t) => t.id), ['0004', '0005']);
    });

    test('busca por código, ubicación o categoría sin importar tildes', () {
      expect(filterTickets(tickets, TicketFilter.all, '#REP-0003').map((t) => t.id), ['0003']);
      expect(filterTickets(tickets, TicketFilter.all, 'sala b').map((t) => t.id), ['0005']);
      expect(filterTickets(tickets, TicketFilter.all, 'electrica').map((t) => t.id), ['0001']);
    });
  });

  group('Línea de tiempo del detalle', () {
    final created = DateTime(2026, 11, 10, 10, 42);

    test('marca la fase actual, deja hechas las anteriores y pendientes las siguientes', () {
      final steps = buildTimeline(TicketStatus.inProgress, createdAt: created);
      expect(steps.length, 6);
      expect(steps.map((s) => s.state), [
        PhaseState.done, PhaseState.done, PhaseState.done, PhaseState.current, PhaseState.pending, PhaseState.pending,
      ]);
      expect(steps.first.date, created);
    });

    test('un rechazo termina en "Rechazado" con su fecha', () {
      final rejectedAt = DateTime(2026, 11, 11, 9, 20);
      final steps = buildTimeline(TicketStatus.rejected, createdAt: created, closedAt: rejectedAt);
      expect(steps.map((s) => s.status), [TicketStatus.received, TicketStatus.inReview, TicketStatus.rejected]);
      expect(steps.last.state, PhaseState.current);
      expect(steps.last.date, rejectedAt);
    });
  });

  group('Detalle desde la API', () {
    Map<String, dynamic> json(String status, {String? reason}) => {
          'id': '15',
          'code': 'REP-0015',
          'category': 'Eléctrica',
          'title': 'Enchufe quemado',
          'description': 'El enchufe de la pared echa chispas',
          'status': status,
          'priority': null,
          'location': 'Piso 2',
          'createdAt': '2026-11-10T13:30:00.000Z',
          'hasPhoto': true,
          'rejectionReason': reason,
          'comments': [
            {'id': '2', 'author': 'Servicios Generales', 'createdAt': '2026-11-10T15:00:00.000Z', 'text': 'Técnico en camino'},
            {'id': '1', 'author': 'Servicios Generales', 'createdAt': '2026-11-10T14:00:00.000Z', 'text': 'Recibido'},
          ],
        };

    test('lee los comentarios del más antiguo al más nuevo', () {
      final d = TicketDetail.fromJson(json('EN_PROCESO'));
      expect(d.comments.map((c) => c.text), ['Recibido', 'Técnico en camino']);
      expect(d.hasPhoto, isTrue);
    });

    test('el motivo solo se muestra si el ticket está rechazado', () {
      expect(TicketDetail.fromJson(json('EN_PROCESO', reason: 'algo')).visibleRejectionReason, isNull);
      expect(TicketDetail.fromJson(json('RECHAZADO', reason: 'Lo ve el edificio')).visibleRejectionReason, 'Lo ve el edificio');
    });

    test('lee el historial real y marca el estado actual en la línea de tiempo', () {
      final detail = TicketDetail.fromJson({
        ...json('AUTOGESTION'),
        'timeline': [
          {'status': 'RECIBIDO', 'previousStatus': null, 'date': '2026-11-10T13:30:00.000Z', 'current': false},
          {'status': 'AUTOGESTION', 'previousStatus': 'RECIBIDO', 'date': '2026-11-10T14:00:00.000Z', 'current': true},
        ],
      });

      final steps = buildTimeline(
        detail.ticket.status,
        createdAt: detail.ticket.createdAt,
        history: detail.timeline,
      );
      expect(steps.map((step) => step.status), [TicketStatus.received, TicketStatus.selfHelp]);
      expect(steps.map((step) => step.state), [PhaseState.done, PhaseState.current]);
      expect(steps.last.description, 'Cambio de Recibido a Autogestión.');
      expect(steps.last.date, isNotNull);
    });
  });
}
