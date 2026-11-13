import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/format/ticket_time.dart';
import 'package:tyckops/core/navigation/routes.dart';
import 'package:tyckops/core/network/api_exception.dart';
import 'package:tyckops/core/network/token_storage.dart';
import 'package:tyckops/data/models/app_user.dart';
import 'package:tyckops/data/models/ticket.dart';
import 'package:tyckops/data/models/ticket_status.dart';
import 'package:tyckops/data/models/user_role.dart';
import 'package:tyckops/data/repositories/ticket_repository.dart';
import 'package:tyckops/features/auth/auth_session.dart';
import 'package:tyckops/features/worker/home/worker_home_screen.dart';
import 'package:tyckops/features/worker/my_tickets_store.dart';

/// Guarda el token en memoria (las pruebas no tienen almacenamiento seguro).
class _MemoryTokenStorage implements TokenStorage {
  String? _token;
  @override
  Future<void> saveToken(String token) async => _token = token;
  @override
  Future<String?> readToken() async => _token;
  @override
  Future<void> clear() async => _token = null;
}

class _StubTickets implements TicketRepository {
  _StubTickets(this.result);
  Object result; // MyTickets o una excepción
  @override
  Future<MyTickets> myTickets() async => result is MyTickets ? result as MyTickets : throw result;
}

AppUser _user(String id) => AppUser(id: id, name: 'Ana', email: 'ana@gamaitaly.cl', role: UserRole.worker, termsAccepted: true);

void main() {
  test('el saludo usa el nombre de quien inició sesión', () {
    expect(greetingFor('Pedro Fernández'), 'Hola, Pedro Fernández');
    expect(greetingFor('Camilo Muñoz'), 'Hola, Camilo Muñoz');
    expect(greetingFor('  '), 'Hola');
    expect(greetingFor(null), 'Hola');
  });

  group('Fecha corta de los tickets (mockup home)', () {
    final now = DateTime(2026, 11, 16, 12);
    test('hoy, ayer y fecha con mes', () {
      expect(formatTicketTime(DateTime(2026, 11, 16, 10, 30), now: now), 'Hoy, 10:30 hrs');
      expect(formatTicketTime(DateTime(2026, 11, 15, 16, 45), now: now), 'Ayer, 16:45 hrs');
      expect(formatTicketTime(DateTime(2026, 5, 14, 9, 15), now: now), '14 May, 09:15 hrs');
      expect(formatTicketTime(DateTime(2025, 12, 1, 8, 0), now: now), '1 Dic 2025, 08:00 hrs');
    });
  });

  group('Ticket desde la API', () {
    Map<String, dynamic> json(String id, String status) => {
          'id': id,
          'code': 'REP-0142',
          'category': 'Electricidad',
          'title': 'Enchufe en mal estado',
          'status': status,
          'priority': 'ALTA',
          'location': 'Recepción central',
          'createdAt': '2026-11-16T13:30:00.000Z',
        };

    test('lee el ticket y sabe si sigue activo', () {
      final t = Ticket.fromJson(json('t-0142', 'EN_PROCESO'));
      expect(t.status, TicketStatus.inProgress);
      expect(t.priority, TicketPriority.high);
      expect(t.isActive, isTrue);
      expect(Ticket.fromJson(json('t-1', 'CERRADO')).isActive, isFalse);
    });

    test('rechaza ids que podrían alterar la URL', () {
      expect(() => Ticket.fromJson(json('../admin', 'EN_PROCESO')), throwsFormatException);
      expect(Ticket.isSafeId('t-0142'), isTrue);
      expect(Ticket.isSafeId('a/b'), isFalse);
      expect(Routes.workerTicketDetail('t-0142'), '/worker/solicitudes/t-0142');
    });
  });

  group('MyTicketsStore', () {
    final sample = MyTickets(
      tickets: [
        Ticket(id: 't-1', code: 'REP-1', category: 'Baños', title: 'Fuga', status: TicketStatus.inReview, priority: TicketPriority.medium, location: 'Piso 2', createdAt: DateTime(2026, 11, 16)),
      ],
      total: 5,
      inAttention: 1,
      slaPercent: 98.4,
    );

    test('carga los tickets y los borra al cerrar sesión', () async {
      final session = AuthSession(_MemoryTokenStorage());
      await session.signIn(_user('w-1'), 'token');
      final store = MyTicketsStore(_StubTickets(sample), session);

      await store.loadIfNeeded();
      expect(store.data?.inAttention, 1);

      await session.signOut();
      expect(store.data, isNull, reason: 'el siguiente usuario no debe ver estos tickets');
    });

    test('muestra el mensaje del servidor si falla', () async {
      final session = AuthSession(_MemoryTokenStorage());
      await session.signIn(_user('w-1'), 'token');
      final store = MyTicketsStore(
        _StubTickets(const ApiException('Sin conexión con el servidor.', statusCode: 0)),
        session,
      );

      await store.load();
      expect(store.data, isNull);
      expect(store.error, 'Sin conexión con el servidor.');
    });
  });
}
