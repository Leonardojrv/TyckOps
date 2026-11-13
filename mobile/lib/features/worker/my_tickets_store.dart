import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/ticket.dart';
import '../../data/repositories/ticket_repository.dart';
import '../auth/auth_session.dart';

/// Tickets del colaborador compartidos por el home y la barra inferior
/// (el número sobre "Mis solicitudes").
class MyTicketsStore extends ChangeNotifier {
  MyTicketsStore(this._repository, this._session) {
    _session.addListener(_onSessionChanged);
  }

  final TicketRepository _repository;
  final AuthSession _session;

  MyTickets? _data;
  String? _error;
  bool _loading = false;
  String? _ownerId; // de quién son los datos que hay en memoria

  MyTickets? get data => _data;
  String? get error => _error;
  bool get loading => _loading;

  /// Carga solo si todavía no hay datos (al abrir el home).
  Future<void> loadIfNeeded() async {
    if (_data == null && _error == null) await load();
  }

  /// Vuelve a pedir los tickets (deslizar hacia abajo o "Reintentar").
  Future<void> load() async {
    final userId = _session.user?.id;
    if (userId == null || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _repository.myTickets();
      if (_session.user?.id != userId) return; // cerró sesión mientras cargaba
      _data = data;
      _ownerId = userId;
    } on ApiException catch (e) {
      if (_session.user?.id == userId) _error = e.message;
    } on FormatException {
      if (_session.user?.id == userId) _error = 'No pudimos leer tus solicitudes. Intenta nuevamente.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Seguridad: si cierra sesión o entra otra persona, se borran los tickets
  // del usuario anterior para que nunca aparezcan en la pantalla del siguiente.
  void _onSessionChanged() {
    if (_session.user?.id == _ownerId) return;
    _data = null;
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
