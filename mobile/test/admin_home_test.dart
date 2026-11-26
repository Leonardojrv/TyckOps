// ¿PARA QUÉ SIRVE?
//   Prueba el Home del administrador y el "Listado de personal" (T13).
//
// ¿QUÉ HACE?
//   Revisa el criterio de la tarea (cada una de las cinco opciones lleva a su
//   pantalla), los textos del mockup, la búsqueda y filtros del personal y las
//   etiquetas de tickets de cada persona.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias una opción, un texto o una regla del listado, ajusta esta prueba
//   y corre `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tyckops/core/navigation/routes.dart';
import 'package:tyckops/core/network/token_storage.dart';
import 'package:tyckops/data/models/app_user.dart';
import 'package:tyckops/data/models/staff_member.dart';
import 'package:tyckops/data/models/user_role.dart';
import 'package:tyckops/data/repositories/admin_repository.dart';
import 'package:tyckops/features/admin/home/admin_home_screen.dart';
import 'package:tyckops/features/admin/staff/staff_logic.dart';
import 'package:tyckops/features/auth/auth_session.dart';

class _MemoryTokenStorage implements TokenStorage {
  String? _token;
  @override
  Future<void> saveToken(String token) async => _token = token;
  @override
  Future<String?> readToken() async => _token;
  @override
  Future<void> clear() async => _token = null;
}

const _people = [
  StaffMember(id: '1', name: 'Camila Soto Valenzuela', email: 'camila.soto@gamaitaly.cl', role: UserRole.worker, area: 'Tesorería', tickets: StaffTickets(active: 2)),
  StaffMember(id: '2', name: 'Rodrigo Palma', email: 'rodrigo@gmail.com', role: UserRole.worker, area: 'Marketing', tickets: StaffTickets(active: 1, urgent: 1)),
  StaffMember(id: '3', name: 'Ignacio Cruz', email: 'ignacio@gamaitaly.cl', role: UserRole.worker, area: 'Marketing'),
  StaffMember(id: '4', name: 'Marcela Fuentes', email: 'marcela@outlook.com', role: UserRole.admin, area: 'Ventas Masivo', tickets: StaffTickets(resolvedToday: 1)),
];

// El punto que "late" se anima siempre: se avanza el tiempo a mano en vez de
// esperar a que todo quede quieto (pumpAndSettle nunca terminaría).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('Listado de personal', () {
    test('áreas con su cantidad, de la más grande a la más chica', () {
      expect(areasOf(_people).map((a) => '${a.area} ${a.count}'), ['Marketing 2', 'Tesorería 1', 'Ventas Masivo 1']);
    });

    test('busca por nombre, área o correo sin importar tildes', () {
      expect(filterStaff(_people, query: 'tesoreria').map((p) => p.id), ['1']);
      expect(filterStaff(_people, query: 'gmail').map((p) => p.id), ['2']);
      expect(filterStaff(_people, query: 'marketing cruz').map((p) => p.id), ['3']);
      expect(filterStaff(_people, area: 'Marketing').length, 2);
      expect(filterStaff(_people, role: UserRole.admin).map((p) => p.id), ['4']);
    });

    test('la etiqueta muestra lo más importante de cada persona', () {
      expect(ticketBadge(_people[0].tickets).text, '2 tickets abiertos');
      expect(ticketBadge(_people[1].tickets).kind, BadgeKind.urgent);
      expect(ticketBadge(_people[2].tickets).text, 'Sin tickets');
      expect(ticketBadge(_people[3].tickets).text, '1 resuelto hoy');
      expect(ticketBadge(const StaffTickets(active: 3, inProgress: 3)).text, '3 en proceso');
    });

    test('lee el servidor y descarta personas incompletas', () {
      expect(StaffMember.tryParse({'id': 1, 'nombre': '', 'email': 'x@gamaitaly.cl'}), isNull);
      final p = StaffMember.tryParse({'id': 2, 'nombre': 'Ana', 'email': 'ana@gamaitaly.cl', 'rol': 'ADMINISTRADOR', 'area': 'RRHH'})!;
      expect(p.role, UserRole.admin);
      expect(p.area, 'RRHH');
    });
  });

  testWidgets('Home: las cinco opciones del mockup y cada una lleva a su pantalla', (tester) async {
    tester.view.physicalSize = const Size(1500, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = AuthSession(_MemoryTokenStorage());
    await session.signIn(const AppUser(id: 'a-1', name: 'Felipe Morales', email: 'felipe@gamaitaly.cl', role: UserRole.admin), 't');

    Widget dest(String name) => Scaffold(body: Text('pantalla:$name'));
    final router = GoRouter(
      initialLocation: Routes.adminHome,
      routes: [
        GoRoute(path: Routes.adminHome, builder: (c, s) => AdminHomeScreen(session: session, repository: FakeAdminRepository())),
        GoRoute(path: Routes.adminNewTicket, builder: (c, s) => dest('generar')),
        GoRoute(path: Routes.adminPriority, builder: (c, s) => dest('prioridad')),
        GoRoute(path: Routes.adminHistory, builder: (c, s) => dest('historial')),
        GoRoute(path: Routes.adminStaff, builder: (c, s) => dest('personal')),
        GoRoute(path: Routes.adminDashboard, builder: (c, s) => dest('dashboard')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _settle(tester);

    expect(find.text('Hola, Felipe Morales'), findsOneWidget);
    expect(find.text('Carga .txt de autoayuda y prioridad Media/Alta'), findsOneWidget);
    expect(find.text('5 Secciones'), findsOneWidget);
    expect(find.text('8'), findsOneWidget, reason: 'tickets pendientes del modo de prueba');

    for (final (title, screen) in [
      ('Generar ticket', 'generar'),
      ('Asignación de prioridad', 'prioridad'),
      ('Historial de reparaciones', 'historial'),
      ('Listado de personal', 'personal'),
      ('Dashboard', 'dashboard'),
    ]) {
      await tester.tap(find.text(title));
      await _settle(tester);
      expect(find.text('pantalla:$screen'), findsOneWidget, reason: title);
      router.go(Routes.adminHome);
      await _settle(tester);
    }
  });
}
