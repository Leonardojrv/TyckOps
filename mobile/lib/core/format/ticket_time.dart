// ¿PARA QUÉ SIRVE?
//   Escribe las fechas de los tickets de forma corta y fácil de leer.
//
// ¿QUÉ HACE?
//   Convierte una fecha en "Hoy, 10:30 hrs", "Ayer, 16:45 hrs" o
//   "14 May, 09:15 hrs", como en los mockups.
//
// ¿CÓMO LO CAMBIO?
//   Si quieres otro formato (por ejemplo, sin "hrs"), cámbialo aquí y se aplica
//   en toda la app. Corre test/worker_home_test.dart para confirmar.

const _months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Fecha sin hora, como en el historial: "02 May 2026".
String formatTicketDate(DateTime date) => '${_two(date.day)} ${_months[date.month - 1]} ${date.year}';

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
