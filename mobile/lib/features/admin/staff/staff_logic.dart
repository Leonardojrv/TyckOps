// ¿PARA QUÉ SIRVE?
//   Reúne las reglas del "Listado de personal" (T13) que no dependen del diseño,
//   para poder probarlas (test/admin_home_test.dart).
//
// ¿QUÉ HACE?
//   Arma las áreas para los filtros (con cuántas personas tiene cada una), busca
//   por nombre, área o correo (sin importar tildes ni mayúsculas) y decide qué
//   etiqueta lleva cada persona ("2 tickets abiertos", "1 ticket urgente"...).
//
// ¿CÓMO LO CAMBIO?
//   Para cambiar el orden de prioridad de las etiquetas, edita `ticketBadge`.

import '../../../data/models/staff_member.dart';
import '../../../data/models/user_role.dart';

/// Quita tildes y mayúsculas para que "tesoreria" encuentre "Tesorería".
String plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll('ñ', 'n');

/// Áreas con su cantidad de personas, de la más grande a la más chica.
List<({String area, int count})> areasOf(List<StaffMember> people) {
  final counts = <String, int>{};
  for (final p in people) {
    final a = p.area;
    if (a != null) counts[a] = (counts[a] ?? 0) + 1;
  }
  return [for (final e in counts.entries) (area: e.key, count: e.value)]
    ..sort((a, b) => b.count != a.count ? b.count.compareTo(a.count) : a.area.compareTo(b.area));
}

/// Filtra por área (null = todas), rol (null = todos) y texto (cada palabra
/// debe aparecer en el nombre, el área o el correo, en cualquier orden).
List<StaffMember> filterStaff(List<StaffMember> people, {String? area, UserRole? role, String query = ''}) {
  final words = plain(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return [
    for (final p in people)
      if ((area == null || p.area == area) &&
          (role == null || p.role == role) &&
          words.every(plain('${p.name} ${p.area ?? ''} ${p.email}').contains))
        p,
  ];
}

/// Tipos de etiqueta de la tarjeta (cada uno con su color en la pantalla).
enum BadgeKind { urgent, open, inProgress, resolved, none }

/// La etiqueta más importante de la persona, como en el mockup.
({BadgeKind kind, String text}) ticketBadge(StaffTickets t) {
  if (t.urgent > 0) return (kind: BadgeKind.urgent, text: t.urgent == 1 ? '1 ticket urgente' : '${t.urgent} tickets urgentes');
  if (t.inProgress > 0 && t.inProgress == t.active) return (kind: BadgeKind.inProgress, text: '${t.inProgress} en proceso');
  if (t.active > 0) return (kind: BadgeKind.open, text: t.active == 1 ? '1 ticket abierto' : '${t.active} tickets abiertos');
  if (t.resolvedToday > 0) return (kind: BadgeKind.resolved, text: t.resolvedToday == 1 ? '1 resuelto hoy' : '${t.resolvedToday} resueltos hoy');
  return (kind: BadgeKind.none, text: 'Sin tickets');
}
