// ¿PARA QUÉ SIRVE?
//   Reúne las reglas del "Historial de Solicitudes" (T9) que no dependen del
//   diseño, para poder probarlas (test/history_test.dart).
//
// ¿QUÉ HACE?
//   Define los filtros de fecha (Rango), de estado y de tipo (categoría), busca
//   por código, descripción, ubicación o fecha, y calcula el tiempo promedio de
//   resolución que se muestra en la pantalla.
//
// ¿CÓMO LO CAMBIO?
//   Para agregar un rango (por ejemplo "Últimos 6 meses") o un estado, súmalo a
//   su enum. El texto de cada opción es el que aparece en la pantalla.

import '../../../core/format/ticket_time.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/ticket_status.dart';

/// Filtro "Rango": qué tan atrás mirar.
enum HistoryRange {
  last7('Últimos 7 días', 7),
  last30('Últimos 30 días', 30),
  last90('Últimos 90 días', 90),
  thisYear('Este año', null),
  all('Todo el historial', null);

  const HistoryRange(this.label, this.days);

  final String label;
  final int? days;

  /// ¿La fecha cae dentro del rango? Se cuenta por días completos (hoy incluido).
  bool includes(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      HistoryRange.all => true,
      HistoryRange.thisYear => date.year == now.year,
      _ => !date.isBefore(today.subtract(Duration(days: days! - 1))),
    };
  }
}

/// Filtro "Estado". "Finalizados" es el que muestra el mockup por defecto.
enum HistoryStatus {
  finished('Finalizados'), // resuelto, cerrado, rechazado o cancelado
  all('Todos'),
  active('En curso'),
  resolved('Resueltos y cerrados'),
  rejected('Rechazados'),
  cancelled('Cancelados');

  const HistoryStatus(this.label);

  final String label;

  bool matches(Ticket t) => switch (this) {
        HistoryStatus.finished => !t.isActive,
        HistoryStatus.all => true,
        HistoryStatus.active => t.isActive,
        HistoryStatus.resolved => t.status == TicketStatus.resolved || t.status == TicketStatus.closed,
        HistoryStatus.rejected => t.status == TicketStatus.rejected,
        HistoryStatus.cancelled => t.status == TicketStatus.cancelled,
      };
}

/// El ticket ya terminó y sabemos cuándo: el historial muestra "Finalizado: ...".
bool isFinished(Ticket t) => !t.isActive && t.closedAt != null;

/// La fecha con que se filtra y se muestra: la de término si ya terminó,
/// si no, la de creación.
DateTime historyDate(Ticket t) => isFinished(t) ? t.closedAt! : t.createdAt;

/// Quita tildes y mayúsculas para que "baño" encuentre "Baños".
String _plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u');

/// Aplica Rango + Estado + Tipo + búsqueda. Devuelve del más reciente al más antiguo.
///
/// La búsqueda acepta el código ("0142" o "#REP-0142"), palabras de la
/// descripción o la ubicación, y fechas como aparecen en la tarjeta ("02 may").
/// Cada palabra debe aparecer en algún lado del ticket, en cualquier orden.
List<Ticket> filterHistory(
  List<Ticket> tickets, {
  required HistoryRange range,
  required HistoryStatus status,
  String? category, // null = todos los tipos
  String query = '',
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final words = _plain(query.replaceAll('#', ' ')).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  final isNumber = RegExp(r'^\d+$');

  bool hits(Ticket t) {
    if (words.isEmpty) return true;
    final text = _plain([
      t.code,
      t.title,
      t.location,
      t.category,
      t.status.label,
      formatTicketDate(t.createdAt),
      if (t.closedAt != null) formatTicketDate(t.closedAt!),
    ].join(' '));
    // Los números se comparan enteros ("20" es el día 20, no el "20" de "2026"),
    // salvo dentro del código, donde "142" sí encuentra "REP-0142".
    final numbers = text.split(RegExp(r'[^0-9]+')).toSet();
    final codeDigits = t.code.replaceAll(RegExp(r'\D'), '');
    return words.every((w) => isNumber.hasMatch(w) ? numbers.contains(w) || codeDigits.contains(w) : text.contains(w));
  }

  return [
    for (final t in tickets)
      if (status.matches(t) &&
          range.includes(historyDate(t), today) &&
          (category == null || t.category == category) &&
          hits(t))
        t,
  ]..sort((a, b) => historyDate(b).compareTo(historyDate(a)));
}

/// Los tipos (categorías) que hay en tus tickets, en orden alfabético.
List<String> categoriesOf(List<Ticket> tickets) => {for (final t in tickets) t.category}.toList()..sort();

/// Tiempo promedio desde que se reportó hasta que se resolvió o cerró.
/// null si todavía no hay tickets resueltos con fecha de término.
Duration? averageResolution(List<Ticket> tickets) {
  final times = [
    for (final t in tickets)
      if ((t.status == TicketStatus.resolved || t.status == TicketStatus.closed) && t.closedAt != null)
        t.closedAt!.difference(t.createdAt),
  ];
  if (times.isEmpty) return null;
  final total = times.fold<int>(0, (sum, d) => sum + d.inMinutes);
  return Duration(minutes: total ~/ times.length);
}

/// "4.2 hrs" · "2.5 días": el promedio corto que muestra el mockup.
String formatAverage(Duration d) {
  final hours = d.inMinutes / 60;
  if (hours < 48) return '${hours.toStringAsFixed(1)} hrs';
  return '${(hours / 24).toStringAsFixed(1)} días';
}
