// ¿PARA QUÉ SIRVE?
//   Guarda tus tickets para que varias pantallas los compartan.
//
// ¿QUÉ HACE?
//   Los pide al servidor, los guarda mientras la sesión esté abierta y los BORRA al
//   cerrar sesión, para que la siguiente persona nunca los vea.
//
// ¿CÓMO LO CAMBIO?
//   Si otra pantalla necesita los tickets, úsala con este mismo store en vez de
//   pedirlos de nuevo.

import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/self_help.dart';
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

  /// El mismo repositorio, para pantallas que piden más datos de un ticket
  /// (por ejemplo el detalle de la T7). Así no hay que pasarlo por todos lados.
  TicketRepository get repository => _repository;

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

  /// T9 · Cancela un ticket y vuelve a pedir la lista, para que el home, el
  /// contador de la barra y el historial muestren el estado nuevo.
  /// Si el servidor lo rechaza (por ejemplo, ya está en revisión), lanza la
  /// [ApiException] para que la pantalla muestre el mensaje.
  Future<Ticket> cancelTicket(String id) async {
    final cancelled = await _repository.cancelTicket(id);
    await load();
    return cancelled;
  }

  /// T10 · "Cerrar ticket" o "Reportar a administración" desde la guía, y
  /// vuelve a pedir la lista para que todo muestre el estado nuevo.
  Future<Ticket> resolveGuide(String id, GuideAction action) async {
    final updated = await _repository.resolveGuide(id, action);
    await load();
    return updated;
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
