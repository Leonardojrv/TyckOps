// ¿PARA QUÉ SIRVE?
//   Es quien le pide al servidor tus tickets.
//
// ¿QUÉ HACE?
//   Trae la lista (home y Mis solicitudes), el detalle de uno y su foto. Nunca envía
//   tu id de usuario: el servidor lo saca de tu sesión.
//
// ¿CÓMO LO CAMBIO?
//   Si agregas una acción sobre tickets (por ejemplo, cancelar en la T8), súmala
//   aquí y en la versión de prueba (FakeTicketRepository).

import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/self_help.dart';
import '../models/ticket.dart';
import '../models/ticket_detail.dart';
import '../models/ticket_status.dart';

/// Acceso a los tickets del colaborador (home, lista y detalle).
///
/// Regla de seguridad: el servidor decide de quién son los tickets a partir
/// del token. La app NUNCA envía el id del usuario, solo el id del ticket, y
/// el servidor responde 404 si ese ticket no es tuyo.
abstract class TicketRepository {
  /// Todos tus tickets y el resumen del home.
  Future<MyTickets> myTickets();

  /// El detalle completo de un ticket tuyo (T7).
  Future<TicketDetail> ticketDetail(String id);

  /// La foto adjunta de un ticket tuyo, como bytes (solo en memoria).
  Future<Uint8List> ticketPhoto(String id);

  /// T9 · Cancela un ticket tuyo. Solo funciona mientras está Recibido: si ya
  /// avanzó, el servidor responde 409 y aquí llega como [ApiException].
  Future<Ticket> cancelTicket(String id);

  /// T10 · La guía paso a paso de un ticket tuyo de prioridad Baja.
  Future<SelfHelpGuide> selfHelpGuide(String id);

  /// T10 · "Cerrar ticket" (la guía funcionó) o "Reportar a administración".
  /// Si el ticket ya no admite la guía, el servidor responde 409.
  Future<Ticket> resolveGuide(String id, GuideAction action);
}

class ApiTicketRepository implements TicketRepository {
  ApiTicketRepository(this._api);

  final ApiClient _api;

  @override
  Future<MyTickets> myTickets() async {
    final body = await _api.get<Map<String, dynamic>>('/tickets/mis-tickets');
    final data = body['data'];
    if (data is! Map) throw const FormatException('Respuesta de tickets inválida');
    return MyTickets.fromJson(data.cast<String, dynamic>());
  }

  @override
  Future<TicketDetail> ticketDetail(String id) async {
    _checkId(id);
    final body = await _api.get<Map<String, dynamic>>('/tickets/${Uri.encodeComponent(id)}');
    final ticket = (body['data'] as Map?)?['ticket'];
    if (ticket is! Map) throw const FormatException('Respuesta de detalle inválida');
    return TicketDetail.fromJson(ticket.cast<String, dynamic>());
  }

  @override
  Future<Uint8List> ticketPhoto(String id) {
    _checkId(id);
    return _api.getBytes('/tickets/${Uri.encodeComponent(id)}/foto');
  }

  @override
  Future<Ticket> cancelTicket(String id) async {
    _checkId(id);
    final body = await _api.post<Map<String, dynamic>>('/tickets/${Uri.encodeComponent(id)}/cancelar');
    final ticket = (body['data'] as Map?)?['ticket'];
    if (ticket is! Map) throw const FormatException('Respuesta de cancelación inválida');
    return Ticket.fromJson(ticket.cast<String, dynamic>());
  }

  @override
  Future<SelfHelpGuide> selfHelpGuide(String id) async {
    _checkId(id);
    final body = await _api.get<Map<String, dynamic>>('/tickets/${Uri.encodeComponent(id)}/guia');
    final guide = (body['data'] as Map?)?['guia'];
    if (guide is! Map) throw const FormatException('Respuesta de guía inválida');
    return SelfHelpGuide.fromJson(guide.cast<String, dynamic>());
  }

  @override
  Future<Ticket> resolveGuide(String id, GuideAction action) async {
    _checkId(id);
    final body = await _api.post<Map<String, dynamic>>('/tickets/${Uri.encodeComponent(id)}/guia/${action.apiValue}');
    final ticket = (body['data'] as Map?)?['ticket'];
    if (ticket is! Map) throw const FormatException('Respuesta de la guía inválida');
    return Ticket.fromJson(ticket.cast<String, dynamic>());
  }

  // Un id con caracteres raros nunca llega a la URL (evita que alguien arme
  // rutas como "../admin").
  static void _checkId(String id) {
    if (!Ticket.isSafeId(id)) throw const ApiException('No encontramos esa solicitud.', statusCode: 404);
  }
}

/// Datos de prueba para usar la app sin backend (--dart-define=FAKE_AUTH=true).
/// Incluye un ticket rechazado y uno con comentarios para ver todo el detalle.
class FakeTicketRepository implements TicketRepository {
  static DateTime _at(int daysAgo, int h, int m) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - daysAgo, h, m);
  }

  // Lista que se puede modificar: así "Cancelar ticket" funciona en el modo de prueba.
  static final _tickets = [
    // T10: uno de prioridad Baja (muestra la guía) y uno agrupado con el REP-0087.
    Ticket(id: 't-0153', code: 'REP-0153', category: 'Eléctrica', title: 'Falla en tomacorriente de puesto de trabajo', status: TicketStatus.received, priority: TicketPriority.low, location: 'Edificio Central · Piso 2, Puesto 204', createdAt: _at(0, 8, 50)),
    Ticket(id: 't-0152', code: 'REP-0152', category: 'Baños', title: 'Agua en el piso del baño del piso 2', status: TicketStatus.received, priority: null, location: 'Sector Poniente', createdAt: _at(0, 9, 5)),
    Ticket(id: 't-0151', code: 'REP-0151', category: 'Eléctrica', title: 'Luminaria apagada en sala de reuniones B', status: TicketStatus.received, priority: null, location: 'Sala de reuniones B', createdAt: _at(0, 9, 24)),
    Ticket(id: 't-0142', code: 'REP-0142', category: 'Eléctrica', title: 'Enchufe en mal estado', status: TicketStatus.inProgress, priority: TicketPriority.high, location: 'Recepción central', createdAt: _at(0, 10, 30)),
    Ticket(id: 't-0087', code: 'REP-0087', category: 'Baños', title: 'Fuga agua en baño piso 2', status: TicketStatus.inReview, priority: TicketPriority.medium, location: 'Sector Poniente', createdAt: _at(1, 16, 45)),
    Ticket(id: 't-0139', code: 'REP-0139', category: 'Inmobiliario', title: 'Escritorio en malas condiciones', status: TicketStatus.approved, priority: TicketPriority.low, location: 'Piso 4', createdAt: _at(6, 9, 15)),
    Ticket(id: 't-0098', code: 'REP-0098', category: 'Aire acondicionado', title: 'Aire acondicionado gotea en pasillo', status: TicketStatus.rejected, priority: TicketPriority.medium, location: 'Oficinas de Gerencia', createdAt: _at(8, 14, 0), closedAt: _at(7, 9, 20)),
    Ticket(id: 't-0079', code: 'REP-0079', category: 'Inmobiliario', title: 'Soporte de proyector flojo en sala', status: TicketStatus.resolved, priority: TicketPriority.low, location: 'Tesorería', createdAt: _at(12, 11, 0), closedAt: _at(11, 15, 30)),
    Ticket(id: 't-0071', code: 'REP-0071', category: 'Baños', title: 'Cambio de cerradura baño piso 1', status: TicketStatus.closed, priority: TicketPriority.medium, location: 'Baño piso 1', createdAt: _at(20, 8, 10), closedAt: _at(19, 12, 0)),
    Ticket(id: 't-0064', code: 'REP-0064', category: 'Inmobiliario', title: 'Silla con rueda suelta', status: TicketStatus.cancelled, priority: null, location: 'Piso 4', createdAt: _at(45, 10, 0), closedAt: _at(45, 10, 20)),
  ];

  @override
  Future<MyTickets> myTickets() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return MyTickets(
      tickets: List.unmodifiable(_tickets),
      total: _tickets.length,
      inAttention: _tickets.where((t) => t.isActive).length,
      slaPercent: 98.4,
    );
  }

  @override
  Future<TicketDetail> ticketDetail(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final ticket = _tickets.where((t) => t.id == id).firstOrNull;
    if (ticket == null) throw const ApiException('No encontramos esa solicitud.', statusCode: 404);
    return TicketDetail(
      ticket: ticket,
      description: ticket.title,
      hasPhoto: ticket.id == 't-0142',
      rejectionReason: ticket.status == TicketStatus.rejected
          ? 'La reparación requiere un proveedor externo autorizado por la marca del equipo.'
          : null,
      closedAt: ticket.closedAt,
      selfHelp: _selfHelp(ticket),
      closedBySelfHelp: ticket.status == TicketStatus.closed && _guideDecided.contains(ticket.id),
      duplicateOf: ticket.id == 't-0152' ? _original('t-0087') : null,
      comments: ticket.id == 't-0142'
          ? [
              TicketComment(id: '1', author: 'Servicios Generales', createdAt: _at(0, 11, 5), text: 'Revisamos el enchufe: hay daño por sobrecarga. Ya coordinamos el cambio de placa.'),
              TicketComment(id: '2', author: 'Servicios Generales', createdAt: _at(0, 12, 10), text: 'El técnico va en camino con los repuestos. Por favor no uses ese enchufe mientras tanto.'),
            ]
          : const [],
    );
  }

  // Tickets del modo de prueba en los que el colaborador ya usó la guía.
  static final _guideDecided = <String>{};

  static bool _selfHelp(Ticket t) =>
      t.priority == TicketPriority.low && t.status == TicketStatus.received && !_guideDecided.contains(t.id);

  static DuplicateOriginal? _original(String id) {
    final t = _tickets.where((x) => x.id == id).firstOrNull;
    return t == null
        ? null
        : DuplicateOriginal(code: t.code, category: t.category, title: t.title, status: t.status, location: t.location, createdAt: t.createdAt);
  }

  @override
  Future<SelfHelpGuide> selfHelpGuide(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final t = _tickets.where((x) => x.id == id).firstOrNull;
    if (t == null || !_selfHelp(t)) throw const ApiException('Esta solicitud no tiene una guía de autoayuda disponible.', statusCode: 404);
    // Misma guía simulada que entrega el servidor para Eléctrica.
    return const SelfHelpGuide(
      id: 'simulada-electrica',
      title: 'Revisión básica de enchufe o luminaria',
      simulated: true,
      steps: [
        GuideStep(title: 'Inspección visual del cableado', detail: 'Verifique visualmente que el cable y el conector no presenten daños físicos, dobleces agresivos o cortes visibles.'),
        GuideStep(title: 'Comprobación de disyuntor', detail: 'Compruebe que el automático o disyuntor se encuentre activado en el tablero eléctrico secundario del sector.'),
        GuideStep(title: 'Prueba de carga auxiliar', detail: 'Pruebe conectando un equipo auxiliar de baja carga para verificar si el flujo eléctrico se restablece.'),
      ],
    );
  }

  @override
  Future<Ticket> resolveGuide(String id, GuideAction action) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final i = _tickets.indexWhere((t) => t.id == id);
    if (i < 0) throw const ApiException('No encontramos esa solicitud.', statusCode: 404);
    // Misma regla que el servidor: solo mientras la guía aplica, y una sola vez.
    if (!_selfHelp(_tickets[i])) {
      throw const ApiException(
        'Esta solicitud ya fue tomada por Servicios Generales o ya registraste una decisión.',
        statusCode: 409,
        code: 'GUIA_NO_APLICABLE',
      );
    }
    _guideDecided.add(id);
    final t = _tickets[i];
    return _tickets[i] = action == GuideAction.close
        ? t.copyWith(status: TicketStatus.closed, closedAt: DateTime.now())
        : Ticket(id: t.id, code: t.code, category: t.category, title: t.title, status: t.status, priority: TicketPriority.medium, location: t.location, createdAt: t.createdAt);
  }

  @override
  Future<Ticket> cancelTicket(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final i = _tickets.indexWhere((t) => t.id == id);
    if (i < 0) throw const ApiException('No encontramos esa solicitud.', statusCode: 404);
    // Misma regla que el servidor: solo mientras está Recibido.
    if (!_tickets[i].status.canBeCancelled) {
      throw const ApiException(
        'Esta solicitud ya no está en estado Recibido, por eso no se puede cancelar.',
        statusCode: 409,
        code: 'TICKET_NO_CANCELABLE',
      );
    }
    return _tickets[i] = _tickets[i].copyWith(status: TicketStatus.cancelled, closedAt: DateTime.now());
  }

  @override
  Future<Uint8List> ticketPhoto(String id) async {
    // En modo de prueba no hay fotos reales: dibujamos una imagen de ejemplo
    // (un degradado con un círculo) para poder probar el visor en grande.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const size = ui.Size(1200, 900);
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(size.width, size.height), const [ui.Color(0xFF2F3131), ui.Color(0xFF906F6C)]),
    );
    canvas.drawCircle(const ui.Offset(600, 450), 180, ui.Paint()..color = const ui.Color(0xFFD7282F));
    final image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }
}
