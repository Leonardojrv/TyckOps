import '../../core/network/api_client.dart';
import '../models/ticket.dart';
import '../models/ticket_status.dart';

/// Acceso a los tickets del colaborador. El servidor decide de quién son
/// (a partir del token): la app nunca envía el id del usuario.
abstract class TicketRepository {
  Future<MyTickets> myTickets();
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
}

/// Datos de prueba para usar la app sin backend (--dart-define=FAKE_AUTH=true).
class FakeTicketRepository implements TicketRepository {
  @override
  Future<MyTickets> myTickets() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final now = DateTime.now();
    DateTime at(int daysAgo, int h, int m) => DateTime(now.year, now.month, now.day - daysAgo, h, m);
    final tickets = [
      Ticket(id: 't-0142', code: 'REP-0142', category: 'Electricidad', title: 'Enchufe en mal estado', status: TicketStatus.inProgress, priority: TicketPriority.high, location: 'Recepción central', createdAt: at(0, 10, 30)),
      Ticket(id: 't-0087', code: 'REP-0087', category: 'Infraestructura', title: 'Fuga agua en baño piso 2', status: TicketStatus.inReview, priority: TicketPriority.medium, location: 'Sector Poniente', createdAt: at(1, 16, 45)),
      Ticket(id: 't-0139', code: 'REP-0139', category: 'Inmobiliario', title: 'Escritorio en malas condiciones', status: TicketStatus.approved, priority: TicketPriority.low, location: 'Piso 4', createdAt: at(6, 9, 15)),
      Ticket(id: 't-0121', code: 'REP-0121', category: 'Aire acondicionado', title: 'Aire acondicionado no enfría', status: TicketStatus.resolved, priority: TicketPriority.medium, location: 'Sala de reuniones 3', createdAt: at(9, 11, 5)),
    ];
    return MyTickets(tickets: tickets, total: 8, inAttention: 3, slaPercent: 98.4);
  }
}
