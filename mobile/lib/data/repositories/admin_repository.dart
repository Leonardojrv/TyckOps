// ¿PARA QUÉ SIRVE?
//   Habla con el servidor para el Home del administrador y el "Listado de
//   personal" (T13).
//
// ¿QUÉ HACE?
//   Pide el resumen del Home (GET /api/admin/resumen) y el listado de personal
//   (GET /api/admin/personal). Las dos rutas son solo para administradores: el
//   servidor lo revisa con la sesión. La versión de prueba trae datos de ejemplo.
//
// ¿CÓMO LO CAMBIO?
//   Si el servidor cambia una ruta, cámbiala aquí.

import '../../core/network/api_client.dart';
import '../models/staff_member.dart';
import '../models/user_role.dart';

abstract class AdminRepository {
  Future<AdminSummary> summary();
  Future<List<StaffMember>> staff();
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._api);

  final ApiClient _api;

  @override
  Future<AdminSummary> summary() async {
    final data = (await _api.get<Map<String, dynamic>>('/admin/resumen'))['data'];
    if (data is! Map) throw const FormatException('Respuesta de resumen inválida');
    return AdminSummary.fromJson(data.cast<String, dynamic>());
  }

  @override
  Future<List<StaffMember>> staff() async {
    final data = (await _api.get<Map<String, dynamic>>('/admin/personal'))['data'];
    final list = data is Map ? data['personal'] : null;
    if (list is! List) throw const FormatException('Respuesta de personal inválida');
    return [
      for (final item in list)
        if (item is Map) StaffMember.tryParse(item.cast<String, dynamic>()),
    ].whereType<StaffMember>().toList(growable: false);
  }
}

/// Datos de ejemplo para el modo de prueba (--dart-define=FAKE_AUTH=true).
class FakeAdminRepository implements AdminRepository {
  static const _people = [
    StaffMember(id: '1', name: 'Camila Soto Valenzuela', email: 'camila.soto@gamaitaly.cl', role: UserRole.worker, area: 'Tesorería', tickets: StaffTickets(active: 2)),
    StaffMember(id: '2', name: 'Rodrigo Palma Henríquez', email: 'rodrigo.palma@gamaitaly.cl', role: UserRole.worker, area: 'Marketing', tickets: StaffTickets(active: 1, urgent: 1)),
    StaffMember(id: '3', name: 'Ignacio Valenzuela Cruz', email: 'ignacio.valenzuela@gamaitaly.cl', role: UserRole.worker, area: 'Marketing'),
    StaffMember(id: '4', name: 'Marcela Fuentes Rojas', email: 'marcela.fuentes@gamaitaly.cl', role: UserRole.admin, area: 'Ventas Masivo', tickets: StaffTickets(resolvedToday: 1)),
    StaffMember(id: '5', name: 'Esteban Morales Peña', email: 'esteban.morales@gamaitaly.cl', role: UserRole.worker, area: 'Contabilidad', tickets: StaffTickets(active: 3, inProgress: 3)),
    StaffMember(id: '6', name: 'Valentina Ríos Muñoz', email: 'valentina.rios@gmail.com', role: UserRole.worker, area: 'Gerencia'),
  ];

  @override
  Future<AdminSummary> summary() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const AdminSummary(pending: 8, urgent: 2, duplicates: 3, active: 12, staff: 6);
  }

  @override
  Future<List<StaffMember>> staff() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _people;
  }
}
