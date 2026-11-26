// ¿PARA QUÉ SIRVE?
//   Prueba las notificaciones del colaborador (T11).
//
// ¿QUÉ HACE?
//   Revisa que los avisos del servidor se lean bien (y lo raro se descarte),
//   que marcar como leído baje el contador, que los avisos se borren al cerrar
//   sesión, que la ruta del ticket lleve "ver comentarios" cuando corresponde y
//   que la pantalla muestre la lista del mockup.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias textos, tipos de aviso o reglas, ajusta esta prueba y corre
//   `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/navigation/routes.dart';
import 'package:tyckops/core/network/token_storage.dart';
import 'package:tyckops/data/models/app_notification.dart';
import 'package:tyckops/data/models/app_user.dart';
import 'package:tyckops/data/models/ticket_status.dart';
import 'package:tyckops/data/models/user_role.dart';
import 'package:tyckops/data/repositories/notification_repository.dart';
import 'package:tyckops/features/auth/auth_session.dart';
import 'package:tyckops/features/worker/notifications/notifications_screen.dart';
import 'package:tyckops/features/worker/notifications/notifications_store.dart';

class _MemoryTokenStorage implements TokenStorage {
  String? _token;
  @override
  Future<void> saveToken(String token) async => _token = token;
  @override
  Future<String?> readToken() async => _token;
  @override
  Future<void> clear() async => _token = null;
}

Future<AuthSession> _loggedWorker() async {
  final session = AuthSession(_MemoryTokenStorage());
  await session.signIn(
    AppUser(id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', role: UserRole.worker, termsAccepted: true),
    'token',
  );
  return session;
}

void main() {
  group('Datos del servidor', () {
    test('un aviso de comentario trae el ticket y el comentario', () {
      final n = AppNotification.tryParse({
        'id': '7', 'tipo': 'comentario', 'titulo': 'Nuevo comentario en tu ticket', 'cuerpo': '#REP-0087: Revisamos.',
        'leida': false, 'creadaEn': '2026-11-24T12:00:00Z', 'ticketId': '87', 'codigo': 'REP-0087', 'comentarioId': '3',
      })!;
      expect(n.type, NotificationType.comment);
      expect(n.ticketId, '87');
      expect(n.commentId, '3');
    });

    test('se descartan avisos con un tipo o un ticket raro', () {
      expect(AppNotification.tryParse({'id': '1', 'tipo': 'otro', 'creadaEn': '2026-11-24T12:00:00Z', 'ticketId': '87'}), isNull);
      expect(AppNotification.tryParse({'id': '1', 'tipo': 'estado', 'creadaEn': '2026-11-24T12:00:00Z', 'ticketId': '../admin'}), isNull);
      final n = AppNotification.tryParse({'id': '1', 'tipo': 'estado', 'estado': 'EN_PROCESO', 'creadaEn': '2026-11-24T12:00:00Z', 'ticketId': '87'});
      expect(n!.status, TicketStatus.inProgress);
    });
  });

  group('Almacén de avisos', () {
    test('marcar leído baja el contador y cerrar sesión borra todo', () async {
      final session = await _loggedWorker();
      final store = NotificationsStore(FakeNotificationRepository(), session);
      await store.load();
      expect(store.unread, 2);

      final unread = store.feed!.items.firstWhere((n) => !n.read);
      await store.markRead(unread.id);
      expect(store.unread, 1);
      await store.markAllRead();
      expect(store.unread, 0);

      await session.signOut();
      expect(store.feed, isNull, reason: 'los avisos de una persona no quedan para la siguiente');
      store.dispose();
    });
  });

  test('desde "Nuevo comentario" el ticket se abre con los comentarios a la vista', () {
    expect(Routes.workerTicketDetail('87'), '/worker/solicitudes/87');
    expect(Routes.workerTicketDetail('87', focusComments: true), '/worker/solicitudes/87?ver=comentarios');
    expect(Routes.workerNotifications, '/worker/inicio/notificaciones');
    expect(redirectFor(loggedIn: true, role: UserRole.admin, location: Routes.workerNotifications), Routes.adminHome);
  });

  test('hace cuánto llegó el aviso', () {
    final now = DateTime(2026, 11, 24, 12);
    expect(timeAgo(DateTime(2026, 11, 24, 11, 55), now: now), 'Hace 5 min');
    expect(timeAgo(DateTime(2026, 11, 23, 11), now: now), 'Ayer');
    expect(timeAgo(DateTime(2026, 11, 21, 12), now: now), 'Hace 3 días');
  });

  testWidgets('la pantalla muestra la lista del mockup y "Marcar todas leídas"', (tester) async {
    // Más ancho que un celular: en las pruebas cada letra mide un cuadrado
    // completo y los textos salen más anchos que con la fuente real (Inter).
    tester.view.physicalSize = const Size(1500, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = await _loggedWorker();
    final store = NotificationsStore(FakeNotificationRepository(), session);
    await tester.pumpWidget(MaterialApp(home: NotificationsScope(store: store, child: const NotificationsScreen())));
    await tester.pumpAndSettle();

    // La simulación de la pantalla bloqueada ya no se dibuja dentro de la app.
    expect(find.text('PREVISUALIZACIÓN DEL SISTEMA PUSH'), findsNothing);
    expect(find.text('2 nuevas'), findsOneWidget);
    expect(find.text('Nota Admin'), findsOneWidget);
    expect(find.text('#REP-0098'), findsOneWidget);

    final markAll = find.widgetWithText(TextButton, 'Marcar todas leídas');
    await tester.ensureVisible(markAll);
    await tester.tap(markAll);
    await tester.pumpAndSettle();
    expect(find.text('2 nuevas'), findsNothing);
    expect(store.unread, 0);
    store.dispose();
  });
}
