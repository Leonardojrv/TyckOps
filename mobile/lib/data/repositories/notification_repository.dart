// ¿PARA QUÉ SIRVE?
//   Habla con el servidor sobre las notificaciones (T11).
//
// ¿QUÉ HACE?
//   Pide tus avisos, los marca como leídos y registra o quita el token push de
//   este celular. La versión simulada (FAKE_AUTH) trae avisos de ejemplo.
//
// ¿CÓMO LO CAMBIO?
//   Si el servidor cambia una ruta, cámbiala aquí. El servidor decide de quién
//   son los avisos a partir de la sesión: la app nunca envía el id del usuario.

import '../../core/network/api_client.dart';
import '../models/app_notification.dart';
import '../models/ticket_status.dart';

abstract class NotificationRepository {
  Future<NotificationFeed> fetch();
  Future<void> markRead(String id);
  Future<void> markAllRead();

  /// Guarda el token push de este celular para que el servidor le avise.
  Future<void> registerDevice(String token, String platform);
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<NotificationFeed> fetch() async {
    final body = await _api.get<Map<String, dynamic>>('/notificaciones');
    final data = body['data'];
    if (data is! Map) throw const FormatException('Respuesta de notificaciones inválida');
    final items = [
      for (final item in (data['notificaciones'] as List?) ?? const [])
        if (item is Map) AppNotification.tryParse(item.cast<String, dynamic>()),
    ].whereType<AppNotification>().toList(growable: false);
    return NotificationFeed(items: items, unread: (data['sinLeer'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<void> markRead(String id) async {
    // Solo números: un id raro nunca llega a la URL.
    if (!RegExp(r'^\d{1,12}$').hasMatch(id)) return;
    await _api.post<Map<String, dynamic>>('/notificaciones/$id/leida');
  }

  @override
  Future<void> markAllRead() => _api.post<Map<String, dynamic>>('/notificaciones/leidas');

  @override
  Future<void> registerDevice(String token, String platform) =>
      _api.post<Map<String, dynamic>>('/notificaciones/dispositivos', body: {'token': token, 'plataforma': platform});
}

/// Avisos de ejemplo para el modo de prueba (mismos tickets del modo de prueba).
class FakeNotificationRepository implements NotificationRepository {
  static DateTime _ago(Duration d) => DateTime.now().subtract(d);

  final _items = <AppNotification>[
    AppNotification(id: '4', type: NotificationType.statusChange, title: 'Ticket #REP-0142 pasó a "En proceso"', body: 'Tu ticket #REP-0142 cambió a "En proceso". El equipo técnico está trabajando en la reparación.', read: false, createdAt: _ago(const Duration(minutes: 5)), ticketId: 't-0142', ticketCode: 'REP-0142', status: TicketStatus.inProgress),
    AppNotification(id: '3', type: NotificationType.comment, title: 'Nuevo comentario en tu ticket', body: '#REP-0142: El técnico va en camino con los repuestos. Por favor no uses ese enchufe mientras tanto.', read: false, createdAt: _ago(const Duration(minutes: 15)), ticketId: 't-0142', ticketCode: 'REP-0142', commentId: '2'),
    AppNotification(id: '2', type: NotificationType.statusChange, title: 'Ticket #REP-0098 pasó a "Rechazado"', body: 'Tu ticket #REP-0098 cambió a "Rechazado". Motivo: La reparación requiere un proveedor externo autorizado.', read: true, createdAt: _ago(const Duration(days: 1)), ticketId: 't-0098', ticketCode: 'REP-0098', status: TicketStatus.rejected),
    AppNotification(id: '1', type: NotificationType.statusChange, title: 'Ticket #REP-0079 pasó a "Resuelto"', body: 'Tu ticket #REP-0079 cambió a "Resuelto". La reparación terminó. Revisa que todo funcione bien.', read: true, createdAt: _ago(const Duration(days: 3)), ticketId: 't-0079', ticketCode: 'REP-0079', status: TicketStatus.resolved),
  ];

  @override
  Future<NotificationFeed> fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return NotificationFeed(items: List.unmodifiable(_items), unread: _items.where((n) => !n.read).length);
  }

  @override
  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0) _items[i] = _items[i].markedRead();
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].markedRead();
    }
  }

  @override
  Future<void> registerDevice(String token, String platform) async {}
}
