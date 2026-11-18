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

  static final _tickets = [
    Ticket(id: 't-0142', code: 'REP-0142', category: 'Eléctrica', title: 'Enchufe en mal estado', status: TicketStatus.inProgress, priority: TicketPriority.high, location: 'Recepción central', createdAt: _at(0, 10, 30)),
    Ticket(id: 't-0087', code: 'REP-0087', category: 'Baños', title: 'Fuga agua en baño piso 2', status: TicketStatus.inReview, priority: TicketPriority.medium, location: 'Sector Poniente', createdAt: _at(1, 16, 45)),
    Ticket(id: 't-0139', code: 'REP-0139', category: 'Inmobiliario', title: 'Escritorio en malas condiciones', status: TicketStatus.approved, priority: TicketPriority.low, location: 'Piso 4', createdAt: _at(6, 9, 15)),
    Ticket(id: 't-0098', code: 'REP-0098', category: 'Aire acondicionado', title: 'Aire acondicionado gotea en pasillo', status: TicketStatus.rejected, priority: TicketPriority.medium, location: 'Oficinas de Gerencia', createdAt: _at(8, 14, 0)),
    Ticket(id: 't-0079', code: 'REP-0079', category: 'Inmobiliario', title: 'Soporte de proyector flojo en sala', status: TicketStatus.resolved, priority: TicketPriority.low, location: 'Tesorería', createdAt: _at(12, 11, 0)),
  ];

  @override
  Future<MyTickets> myTickets() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return MyTickets(tickets: _tickets, total: _tickets.length, inAttention: 3, slaPercent: 98.4);
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
      closedAt: ticket.status == TicketStatus.rejected ? _at(7, 9, 20) : null,
      comments: ticket.id == 't-0142'
          ? [
              TicketComment(id: '1', author: 'Servicios Generales', createdAt: _at(0, 11, 5), text: 'Revisamos el enchufe: hay daño por sobrecarga. Ya coordinamos el cambio de placa.'),
              TicketComment(id: '2', author: 'Servicios Generales', createdAt: _at(0, 12, 10), text: 'El técnico va en camino con los repuestos. Por favor no uses ese enchufe mientras tanto.'),
            ]
          : const [],
    );
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
