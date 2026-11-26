// ¿PARA QUÉ SIRVE?
//   Son los datos del Home del administrador y del "Listado de personal" (T13).
//
// ¿QUÉ HACE?
//   StaffMember: una persona (nombre, correo, área, rol y resumen de sus tickets).
//   AdminSummary: los números del Home (pendientes, urgentes, duplicados...).
//   Lee lo que manda el servidor y descarta lo que venga incompleto.
//
// ¿CÓMO LO CAMBIO?
//   Si el servidor agrega un dato, súmalo aquí y en su fromJson.

import 'user_role.dart';

/// Resumen de los tickets de una persona (etiqueta de la tarjeta).
class StaffTickets {
  const StaffTickets({this.active = 0, this.urgent = 0, this.inProgress = 0, this.resolvedToday = 0});

  final int active; // en atención (recibido, en revisión, aprobado, en proceso)
  final int urgent; // en atención y con prioridad Alta
  final int inProgress;
  final int resolvedToday;

  factory StaffTickets.fromJson(Map<String, dynamic> json) => StaffTickets(
        active: (json['activos'] as num?)?.toInt() ?? 0,
        urgent: (json['urgentes'] as num?)?.toInt() ?? 0,
        inProgress: (json['enProceso'] as num?)?.toInt() ?? 0,
        resolvedToday: (json['resueltosHoy'] as num?)?.toInt() ?? 0,
      );
}

class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.area,
    this.active = true,
    this.tickets = const StaffTickets(),
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? area; // departamento (Tesorería, Marketing...)
  final bool active;
  final StaffTickets tickets;

  static StaffMember? tryParse(Map<String, dynamic> json) {
    final name = (json['nombre'] as String?)?.trim() ?? '';
    final email = (json['email'] as String?)?.trim() ?? '';
    if (name.isEmpty || email.isEmpty) return null;
    return StaffMember(
      id: json['id'].toString(),
      name: name,
      email: email,
      role: json['rol'] == 'ADMINISTRADOR' ? UserRole.admin : UserRole.worker,
      area: (json['area'] as String?)?.trim().isNotEmpty == true ? (json['area'] as String).trim() : null,
      active: json['activo'] != false,
      tickets: json['tickets'] is Map ? StaffTickets.fromJson((json['tickets'] as Map).cast<String, dynamic>()) : const StaffTickets(),
    );
  }
}

/// Los números de la barra del Home del administrador.
class AdminSummary {
  const AdminSummary({this.pending = 0, this.urgent = 0, this.duplicates = 0, this.active = 0, this.staff = 0});

  final int pending; // esperan una decisión (recibido o en revisión)
  final int urgent; // en atención con prioridad Alta
  final int duplicates; // en atención y agrupados con otro
  final int active; // todos los que siguen en atención
  final int staff; // personas registradas

  factory AdminSummary.fromJson(Map<String, dynamic> json) => AdminSummary(
        pending: (json['pendientes'] as num?)?.toInt() ?? 0,
        urgent: (json['urgentes'] as num?)?.toInt() ?? 0,
        duplicates: (json['duplicados'] as num?)?.toInt() ?? 0,
        active: (json['activos'] as num?)?.toInt() ?? 0,
        staff: (json['personal'] as num?)?.toInt() ?? 0,
      );
}
