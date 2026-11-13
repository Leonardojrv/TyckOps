const _months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Fecha corta de los tickets, como en el mockup:
/// "Hoy, 10:30 hrs" · "Ayer, 16:45 hrs" · "14 May, 09:15 hrs".
///
/// [now] se recibe como parámetro para poder probarla (test/ticket_time_test.dart).
String formatTicketTime(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final dayOf = DateTime(date.year, date.month, date.day);
  final days = DateTime(today.year, today.month, today.day).difference(dayOf).inDays;
  final hour = '${_two(date.hour)}:${_two(date.minute)} hrs';
  if (days == 0) return 'Hoy, $hour';
  if (days == 1) return 'Ayer, $hour';
  final year = date.year == today.year ? '' : ' ${date.year}';
  return '${date.day} ${_months[date.month - 1]}$year, $hour';
}
