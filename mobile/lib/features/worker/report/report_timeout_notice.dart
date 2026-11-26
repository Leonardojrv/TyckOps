// ¿PARA QUÉ SIRVE?
//   Avisa al inicio que se acabó el tiempo para crear un ticket.
//
// ¿QUÉ HACE?
//   "Reportar falla" lo activa cuando vencen los 3 minutos que da el servidor;
//   el inicio lo escucha, muestra el recuadro de alerta y lo marca como visto.
//
// ¿CÓMO LO CAMBIO?
//   El tiempo lo decide el servidor (tickets.sesionCreacion.js). Cuánto se ve
//   la alerta está en worker_home_screen.dart (_TimeoutAlert).

import 'package:flutter/foundation.dart';

class ReportTimeoutNotice extends ChangeNotifier {
  bool _pending = false;

  /// true si hay una alerta que el inicio todavía no muestra.
  bool get pending => _pending;

  /// Se acabó el tiempo: el inicio debe mostrar la alerta.
  void trigger() {
    _pending = true;
    notifyListeners();
  }

  /// El inicio ya la mostró. Devuelve si había una pendiente.
  bool consume() {
    if (!_pending) return false;
    _pending = false;
    return true;
  }
}
