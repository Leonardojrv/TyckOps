// ¿PARA QUÉ SIRVE?
//   Prueba el historial con filtros y la cancelación de tickets (T9).
//
// ¿QUÉ HACE?
//   Revisa los filtros de Rango, Estado y Tipo, la búsqueda por código,
//   descripción o fecha, el tiempo promedio de resolución, y que solo se pueda
//   cancelar un ticket Recibido (en el modo de prueba, igual que el servidor).
//
// ¿CÓMO LO CAMBIO?
//   Si cambias un filtro o la regla de cancelación, ajusta esta prueba y corre
//   `flutter test`.

import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/network/api_exception.dart';
import 'package:tyckops/core/navigation/routes.dart';
import 'package:tyckops/data/models/ticket.dart';
import 'package:tyckops/data/models/ticket_status.dart';
import 'package:tyckops/data/models/user_role.dart';
import 'package:tyckops/data/repositories/ticket_repository.dart';
import 'package:tyckops/features/worker/tickets/history_logic.dart';

final _now = DateTime(2026, 11, 23, 12);

Ticket _t(
  String id,
  TicketStatus status, {
  required DateTime created,
  DateTime? closed,
  String title = 'Falla',
  String category = 'Baños',
}) =>
    Ticket(
      id: id,
      code: 'REP-$id',
      category: category,
      title: title,
      status: status,
      priority: null,
      location: 'Piso 2',
      createdAt: created,
      closedAt: closed,
    );

final _tickets = [
  _t('0001', TicketStatus.received, created: DateTime(2026, 11, 22)),
  _t('0002', TicketStatus.closed, created: DateTime(2026, 11, 10, 8), closed: DateTime(2026, 11, 10, 12), title: 'Cambio de cerradura'),
  _t('0003', TicketStatus.cancelled, created: DateTime(2026, 9, 1), closed: DateTime(2026, 9, 1, 1), category: 'Eléctrica'),
  _t('0004', TicketStatus.resolved, created: DateTime(2026, 11, 20, 8), closed: DateTime(2026, 11, 20, 10)),
  _t('0005', TicketStatus.rejected, created: DateTime(2025, 12, 1), closed: DateTime(2025, 12, 2)),
];

List<String> _ids(List<Ticket> list) => list.map((t) => t.id).toList();

void main() {
  group('Filtros del historial', () {
    test('por defecto (30 días + Finalizados): solo los terminados del último mes, del más reciente al más antiguo', () {
      final r = filterHistory(_tickets, range: HistoryRange.last30, status: HistoryStatus.finished, now: _now);
      expect(_ids(r), ['0004', '0002']);
    });

    test('el rango usa la fecha de término de los finalizados', () {
      expect(_ids(filterHistory(_tickets, range: HistoryRange.last7, status: HistoryStatus.all, now: _now)), ['0001', '0004']);
      expect(_ids(filterHistory(_tickets, range: HistoryRange.last90, status: HistoryStatus.cancelled, now: _now)), ['0003']);
      expect(_ids(filterHistory(_tickets, range: HistoryRange.thisYear, status: HistoryStatus.rejected, now: _now)), isEmpty);
      expect(_ids(filterHistory(_tickets, range: HistoryRange.all, status: HistoryStatus.rejected, now: _now)), ['0005']);
    });

    test('estado y tipo', () {
      expect(_ids(filterHistory(_tickets, range: HistoryRange.all, status: HistoryStatus.active, now: _now)), ['0001']);
      expect(_ids(filterHistory(_tickets, range: HistoryRange.all, status: HistoryStatus.resolved, now: _now)), ['0004', '0002']);
      expect(
        _ids(filterHistory(_tickets, range: HistoryRange.all, status: HistoryStatus.all, category: 'Eléctrica', now: _now)),
        ['0003'],
      );
      expect(categoriesOf(_tickets), ['Baños', 'Eléctrica']);
    });

    test('la búsqueda encuentra por código, descripción y fecha', () {
      List<String> buscar(String q) =>
          _ids(filterHistory(_tickets, range: HistoryRange.all, status: HistoryStatus.all, query: q, now: _now));
      expect(buscar('#REP-0002'), ['0002']);
      expect(buscar('cerradura'), ['0002']);
      expect(buscar('20 nov'), ['0004']);
      expect(buscar('electrica'), ['0003']);
      expect(buscar('no existe'), isEmpty);
    });

    test('tiempo promedio de resolución (solo resueltos y cerrados)', () {
      // 0002 tardó 4 h y 0004 tardó 2 h → 3 h.
      expect(averageResolution(_tickets), const Duration(hours: 3));
      expect(formatAverage(const Duration(hours: 3)), '3.0 hrs');
      expect(formatAverage(const Duration(days: 3)), '3.0 días');
      expect(averageResolution([_tickets.first]), isNull);
    });
  });

  group('Cancelar ticket (modo de prueba)', () {
    test('solo se cancela un ticket Recibido, y queda con fecha de cierre', () async {
      final repo = FakeTicketRepository();
      final antes = (await repo.myTickets()).tickets;
      final recibido = antes.firstWhere((t) => t.status == TicketStatus.received);
      final enCurso = antes.firstWhere((t) => t.status == TicketStatus.inProgress);

      await expectLater(
        repo.cancelTicket(enCurso.id),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );

      final cancelado = await repo.cancelTicket(recibido.id);
      expect(cancelado.status, TicketStatus.cancelled);
      expect(cancelado.closedAt, isNotNull);
      expect((await repo.myTickets()).tickets.firstWhere((t) => t.id == recibido.id).status, TicketStatus.cancelled);
      // Dos veces no se puede.
      await expectLater(repo.cancelTicket(recibido.id), throwsA(isA<ApiException>()));
    });

    test('el botón solo se ofrece en Recibido', () {
      for (final s in TicketStatus.values) {
        expect(s.canBeCancelled, s == TicketStatus.received, reason: s.name);
      }
    });

    test('la ruta del historial no se confunde con un ticket y es solo del colaborador', () {
      expect(Routes.workerHistory, '/worker/solicitudes/historial');
      expect(redirectFor(loggedIn: true, role: UserRole.admin, location: Routes.workerHistory), Routes.adminHome);
      expect(redirectFor(loggedIn: true, role: UserRole.worker, location: Routes.workerHistory), isNull);
    });
  });
}
