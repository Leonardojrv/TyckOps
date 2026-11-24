// ¿PARA QUÉ SIRVE?
//   Guarda en memoria los avisos del colaborador (T11) para que la campana del
//   encabezado (con su número rojo) y la pantalla "Notificaciones" muestren lo
//   mismo.
//
// ¿QUÉ HACE?
//   Carga los avisos, los marca como leídos y se vacía sola al cerrar sesión
//   (los avisos de una persona nunca se ven en la sesión de otra).
//   NotificationsScope lo pone al alcance de cualquier pantalla.
//
// ¿CÓMO LO CAMBIO?
//   Si cambia la forma de pedir los avisos, cámbiala en notification_repository.dart.

import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/user_role.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../auth/auth_session.dart';

class NotificationsStore extends ChangeNotifier {
  NotificationsStore(this._repository, this._session) {
    _session.addListener(_onSessionChanged);
  }

  final NotificationRepository _repository;
  final AuthSession _session;

  NotificationRepository get repository => _repository;

  NotificationFeed? _feed;
  String? _error;
  bool _loading = false;
  String? _ownerId;

  NotificationFeed? get feed => _feed;
  String? get error => _error;
  bool get loading => _loading;
  int get unread => _feed?.unread ?? 0;

  /// Vuelve a pedir los avisos (al abrir la pantalla, al llegar un push...).
  Future<void> load() async {
    final user = _session.user;
    if (user == null || user.role != UserRole.worker || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final feed = await _repository.fetch();
      if (_session.user?.id != user.id) return; // cerró sesión mientras cargaba
      _feed = feed;
      _ownerId = user.id;
    } on ApiException catch (e) {
      if (_session.user?.id == user.id) _error = e.message;
    } on FormatException {
      if (_session.user?.id == user.id) _error = 'No pudimos leer tus notificaciones. Intenta nuevamente.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Marca un aviso como leído (al tocarlo). Se ve al instante; el servidor se
  /// actualiza por detrás.
  Future<void> markRead(String id) async {
    final feed = _feed;
    final i = feed?.items.indexWhere((n) => n.id == id && !n.read) ?? -1;
    if (feed != null && i >= 0) {
      final items = [...feed.items]..[i] = feed.items[i].markedRead();
      _feed = NotificationFeed(items: items, unread: (feed.unread - 1).clamp(0, 1 << 30));
      notifyListeners();
    }
    try {
      await _repository.markRead(id);
      // Un aviso tocado desde la barra del celular puede no estar aún en la
      // lista: se vuelve a pedir para que el contador quede correcto.
      if (i < 0) await load();
    } on ApiException {
      // Si falla, la próxima carga trae el estado real.
    }
  }

  Future<void> markAllRead() async {
    final feed = _feed;
    if (feed == null || feed.unread == 0) return;
    _feed = NotificationFeed(items: [for (final n in feed.items) n.markedRead()], unread: 0);
    notifyListeners();
    try {
      await _repository.markAllRead();
    } on ApiException {
      await load();
    }
  }

  // Seguridad: al cerrar sesión o cambiar de persona se borran los avisos.
  void _onSessionChanged() {
    if (_session.user?.id == _ownerId) return;
    _feed = null;
    _error = null;
    _ownerId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}

/// Pone el [NotificationsStore] al alcance de cualquier pantalla
/// (`NotificationsScope.of(context)`), y la redibuja cuando cambian los avisos.
class NotificationsScope extends InheritedNotifier<NotificationsStore> {
  const NotificationsScope({super.key, required NotificationsStore store, required super.child}) : super(notifier: store);

  static NotificationsStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationsScope>()?.notifier;
}
