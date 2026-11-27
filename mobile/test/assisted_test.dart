// ¿PARA QUÉ SIRVE?
//   Prueba la asistencia de IA del colaborador (T10): la guía de autoayuda, sus
//   dos acciones y el aviso de ticket duplicado.
//
// ¿QUÉ HACE?
//   Revisa que los datos del servidor se lean bien (y lo raro se descarte), que
//   "Cerrar ticket" solo se habilite al marcar la verificación, que el modo de
//   prueba cumpla las mismas reglas que el servidor y los textos del duplicado.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias una regla o un texto de la T10, ajusta esta prueba y corre
//   `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/network/api_exception.dart';
import 'package:tyckops/data/models/fault_category.dart';
import 'package:tyckops/data/models/self_help.dart';
import 'package:tyckops/data/models/ticket.dart';
import 'package:tyckops/data/models/ticket_detail.dart';
import 'package:tyckops/data/models/ticket_status.dart';
import 'package:tyckops/data/repositories/ticket_repository.dart';
import 'package:tyckops/features/worker/tickets/assisted_guide_view.dart';
import 'package:tyckops/features/worker/tickets/duplicate_ticket_view.dart';
import 'package:tyckops/features/worker/tickets/ticket_logic.dart';

final _ticket = Ticket(
  id: 't-1',
  code: 'REP-0091',
  category: 'Eléctrica',
  title: 'Falla en tomacorriente',
  status: TicketStatus.received,
  priority: TicketPriority.low,
  location: 'Piso 2, Puesto 204',
  createdAt: DateTime(2026, 11, 23, 9),
);

const _guide = SelfHelpGuide(
  id: 'g-1',
  title: 'Revisión básica',
  steps: [GuideStep(title: 'Inspección visual del cableado', detail: 'Revise el cable.'), GuideStep(title: 'Prueba de carga')],
);

void main() {
  group('Datos del servidor', () {
    test('la guía descarta pasos vacíos y reconoce la simulada', () {
      final g = SelfHelpGuide.fromJson({
        'id': 'simulada-electrica',
        'titulo': 'Revisión',
        'origen': 'simulada',
        'pasos': [
          {'titulo': 'Paso 1', 'detalle': 'Hacer algo'},
          {'titulo': '   ', 'detalle': 'sin título'},
          'texto suelto',
        ],
      });
      expect(g.simulated, isTrue);
      expect(g.steps.map((s) => s.title), ['Paso 1']);
    });

    test('el detalle trae la guía y el original del duplicado', () {
      final d = TicketDetail.fromJson({
        'id': '10', 'code': 'REP-0010', 'category': 'Baños', 'title': 'Agua en el piso', 'status': 'RECIBIDO',
        'priority': null, 'location': 'Piso 2', 'createdAt': '2026-11-23T12:00:00Z',
        'selfHelp': false,
        'duplicateOf': {
          'id': '9', 'code': 'REP-0009', 'category': 'Baños', 'title': 'Fuga', 'status': 'EN_REVISION',
          'location': 'Piso 2', 'createdAt': '2026-11-23T11:00:00Z', 'mine': true,
        },
      });
      expect(d.selfHelp, isFalse);
      expect(d.duplicateOf!.code, 'REP-0009');
      expect(d.duplicateOf!.status, TicketStatus.inReview);
      expect(d.duplicateOf!.mine, isTrue);
    });
  });

  group('Pantalla de la guía', () {
    testWidgets('"Cerrar ticket" se habilita solo al marcar la verificación', (tester) async {
      final actions = <GuideAction>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssistedGuideView(
              ticket: _ticket,
              loadGuide: () async => _guide,
              onResolve: (a) async {
                actions.add(a);
                return _ticket;
              },
              onDone: (_) async {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Guía de solución IA'), findsOneWidget);
      expect(find.text('Inspección visual del cableado'), findsOneWidget);

      final close = find.widgetWithText(FilledButton, 'Cerrar ticket (Problema solucionado)');
      expect(tester.widget<FilledButton>(close).onPressed, isNull, reason: 'sin marcar la casilla');

      await tester.tap(find.text('He completado la verificación guiada'));
      await tester.pump();
      expect(tester.widget<FilledButton>(close).onPressed, isNotNull);

      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(actions, [GuideAction.close]);
    });
  });

  group('Modo de prueba (mismas reglas que el servidor)', () {
    test('la guía solo existe en Baja + Autogestión, y se decide una sola vez', () async {
      final repo = FakeTicketRepository();
      final all = (await repo.myTickets()).tickets;
      final low = all.firstWhere((t) => t.priority == TicketPriority.low && t.status == TicketStatus.received);
      expect((await repo.ticketDetail(low.id)).selfHelp, isTrue);
      await repo.startGuide(low.id);
      expect((await repo.selfHelpGuide(low.id)).steps, isNotEmpty);

      final escalated = await repo.resolveGuide(low.id, GuideAction.escalate);
      expect(escalated.priority, TicketPriority.medium);
      expect(escalated.status, TicketStatus.received);
      expect((await repo.ticketDetail(low.id)).selfHelp, isFalse);
      await expectLater(
        repo.resolveGuide(low.id, GuideAction.close),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('hay un ticket agrupado con su original', () async {
      final repo = FakeTicketRepository();
      final details = [for (final t in (await repo.myTickets()).tickets) await repo.ticketDetail(t.id)];
      final dup = details.firstWhere((d) => d.duplicateOf != null);
      expect(dup.duplicateOf!.code, isNot(dup.ticket.code));
    });
  });

  test('cerrado con la guía: la línea de tiempo es Recibido → Autogestión → Cerrado', () {
    final steps = buildTimeline(TicketStatus.closed, createdAt: DateTime(2026, 11, 23), closedBySelfHelp: true);
    expect(steps.map((s) => s.status), [TicketStatus.received, TicketStatus.selfHelp, TicketStatus.closed]);
    expect(steps.last.description, contains('guía de IA'));
    expect(buildTimeline(TicketStatus.closed, createdAt: DateTime(2026, 11, 23)).length, 6);
  });

  group('Textos del duplicado', () {
    test('hace cuánto, categoría y estado operativo', () {
      final now = DateTime(2026, 11, 23, 12);
      expect(timeAgo(DateTime(2026, 11, 23, 11, 15), now: now), 'hace 45 min');
      expect(timeAgo(DateTime(2026, 11, 23, 9), now: now), 'hace 3 h');
      expect(timeAgo(DateTime(2026, 11, 21, 12), now: now), 'hace 2 días');
      expect(categoryFor('Electricidad'), FaultCategory.electrical);
      expect(categoryFor('Aire acondicionado')?.headline, 'Climatización HVAC');
      expect(operationalStatus(TicketStatus.inReview), 'Derivando a un Administrador');
    });
  });
}
