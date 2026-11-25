// ¿PARA QUÉ SIRVE?
//   Conecta la app con las notificaciones push de Firebase (T11), en Android e iOS.
//
// ¿QUÉ HACE?
//   1. Inicia Firebase. Si faltan los archivos de Firebase (google-services.json
//      o GoogleService-Info.plist), no se cae: la app sigue funcionando y la
//      pantalla "Notificaciones" se llena igual desde el servidor.
//   2. Cuando un colaborador inicia sesión: pide permiso para notificar,
//      obtiene el token de este celular y lo registra en el servidor.
//   3. Con la app abierta, muestra el aviso arriba (Android no lo hace solo).
//   4. Al tocar un aviso, abre el ticket correcto; si es "Nuevo comentario",
//      con los comentarios a la vista.
//   5. Al cerrar sesión, borra el token: ese celular deja de recibir avisos.
//
// ¿CÓMO LO CAMBIO?
//   - El canal de Android ("tickets") debe llamarse igual que en el servidor
//     (notificaciones.enviador.js) y en AndroidManifest.xml.
//   - Qué hacer al tocar un aviso: _open.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color, VoidCallback, WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/ticket.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/notification_repository.dart';
import '../../features/auth/auth_session.dart';
import '../../features/worker/notifications/notifications_store.dart';
import '../navigation/routes.dart';

const _channel = AndroidNotificationChannel(
  'tickets',
  'Tus solicitudes',
  description: 'Cambios de estado y comentarios en tus tickets.',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

// Ícono monocromo (android/app/src/main/res/drawable/ic_stat_tyckops.xml) y
// color de marca: los mismos que usa el servidor (notificaciones.enviador.js).
const _androidIcon = 'ic_stat_tyckops';
const _brandColor = Color(0xFFD7282F);

class PushService {
  PushService(this._session, this._repository, this._store);

  final AuthSession _session;
  final NotificationRepository _repository;
  final NotificationsStore _store;
  final _local = FlutterLocalNotificationsPlugin();

  GoRouter? _router;
  Map<String, dynamic>? _pending; // aviso tocado antes de que la app estuviera lista
  String? _pendingFor; // si se sabe, de quién es ese aviso (solo se abre para esa persona)
  // Último aviso abierto: si la sesión vence justo al abrirlo (el servidor
  // responde 401 y la app vuelve al login), se recupera tras iniciar sesión.
  ({Map<String, dynamic> data, String userId, DateTime at})? _lastOpened;
  bool _firebaseReady = false;
  String? _registeredFor; // a quién pertenece el token registrado
  final _subs = <StreamSubscription<dynamic>>[];

  /// true si Firebase está configurado y el push funciona en este celular.
  bool get enabled => _firebaseReady;

  /// Se llama una vez al abrir la app.
  Future<void> start() async {
    _session.addListener(_onSessionChanged);
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      // Sin archivos de Firebase: todo funciona menos el push.
      debugPrint('Push desactivado (Firebase no configurado): $e');
    }
    if (_firebaseReady) await _setUpFirebase();
    _onSessionChanged();
  }

  /// El router se crea después; aquí se conecta y, si alguien ya tocó un aviso, se abre.
  void attachRouter(GoRouter router) {
    _router = router;
    final pending = _pending;
    _pending = null;
    if (pending != null) _open(pending);
  }

  Future<void> _setUpFirebase() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        try {
          _open((jsonDecode(payload) as Map).cast<String, dynamic>());
        } catch (_) {
          // Un aviso con datos raros simplemente no abre nada.
        }
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    final messaging = FirebaseMessaging.instance;
    // iOS: con la app abierta, que el sistema muestre el aviso igual.
    await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    _subs
      ..add(FirebaseMessaging.onMessage.listen(_onForegroundMessage))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data)))
      // Firebase puede renovar el token: se vuelve a registrar en el servidor.
      // ignore: deprecated_member_use
      ..add(messaging.onTokenRefresh.listen((token) => _register(token)));

    // La app estaba cerrada y se abrió tocando un aviso.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _open(initial.data);
  }

  void _onSessionChanged() {
    final user = _session.user;
    // Solo con la sesión completa: después del primer acceso y del código MFA
    // (el permiso se pide al llegar al inicio, no en medio de la configuración).
    if (user != null && user.role == UserRole.worker && !_session.mfaPending && !_session.needsFirstAccess) {
      if (_registeredFor == user.id) return;
      _registeredFor = user.id;
      _store.load();
      if (_firebaseReady) unawaited(_askPermissionAndRegister());
      // Si tocó un aviso antes de iniciar sesión, se abre ahora (si era de
      // otra persona, se descarta).
      final pending = _pending;
      final pendingFor = _pendingFor;
      final router = _router;
      if (pending != null && router != null) {
        _pending = null;
        _pendingFor = null;
        if (pendingFor == null || pendingFor == user.id) _openAfterSignIn(router, pending);
      }
    } else if (user == null && _registeredFor != null) {
      _registeredFor = null;
      // ¿La sesión se cerró justo al abrir un aviso (sesión vencida)? Se
      // guarda para abrirlo apenas la misma persona vuelva a entrar.
      final last = _lastOpened;
      _lastOpened = null;
      if (last != null && _pending == null && DateTime.now().difference(last.at) < const Duration(minutes: 1)) {
        _pending = last.data;
        _pendingFor = last.userId;
      }
      // Cerró sesión: el token se invalida en Firebase, así este celular ya no
      // recibe avisos de esa persona (el servidor lo borra en el próximo envío).
      // ignore: deprecated_member_use
      if (_firebaseReady) unawaited(FirebaseMessaging.instance.deleteToken().catchError((_) {}));
    }
  }

  Future<void> _askPermissionAndRegister() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // Se usa el token de registro clásico de FCM (no el ID de instalación de
      // register()/onRegistered): es el que acepta firebase-admin en el servidor
      // (sendEachForMulticast), igual para Android e iOS.
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('No se pudo registrar el celular para push: $e');
    }
  }

  Future<void> _register(String token) async {
    if (_registeredFor == null) return; // sin sesión no se registra nada
    try {
      await _repository.registerDevice(token, Platform.isIOS ? 'ios' : 'android');
    } catch (e) {
      debugPrint('El servidor no aceptó el token push: $e');
    }
  }

  // Con la app abierta: se muestra el aviso arriba y se actualiza la lista.
  void _onForegroundMessage(RemoteMessage message) {
    _store.load();
    final n = message.notification;
    if (n == null || Platform.isIOS) return; // iOS ya lo muestra solo
    // Mismo "tag" que el servidor: un aviso por ticket y tipo (el nuevo
    // reemplaza al anterior en vez de apilarse). Android reemplaza solo si
    // coinciden tag e id, y Firebase usa id 0 con la app en segundo plano:
    // por eso aquí también va id 0.
    final tag = 'ticket-${message.data['ticketId'] ?? 'general'}-${message.data['tipo'] ?? 'aviso'}';
    _local.show(
      id: 0,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: _androidIcon,
          color: _brandColor,
          tag: tag,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.status,
          ticker: n.title,
          styleInformation: BigTextStyleInformation(n.body ?? '', contentTitle: n.title),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Al terminar el login, el mapa de pantallas (router) también reacciona y
  /// manda al inicio. Si abriéramos el ticket en ese mismo instante, el router
  /// lo pisaría. Por eso se espera a que la app salga de las pantallas de
  /// acceso (login, código MFA, primer acceso) y recién ahí se abre el ticket.
  void _openAfterSignIn(GoRouter router, Map<String, dynamic> data) {
    bool inAuthScreens() {
      final path = router.routerDelegate.currentConfiguration.uri.path;
      return path == Routes.login || path == Routes.mfaVerification || path == Routes.firstAccess;
    }

    if (!inAuthScreens()) {
      _open(data);
      return;
    }
    late final VoidCallback listener;
    listener = () {
      if (inAuthScreens()) return;
      router.routerDelegate.removeListener(listener);
      // Después del cuadro actual: el router ya terminó de ir al inicio.
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(data));
    };
    router.routerDelegate.addListener(listener);
  }

  /// Abre el ticket del aviso. Solo para el colaborador con sesión iniciada.
  void _open(Map<String, dynamic> data) {
    final ticketId = data['ticketId']?.toString() ?? '';
    // Seguridad: un id raro nunca llega a la URL; y el servidor igual responde
    // 404 si el ticket no es tuyo.
    if (!Ticket.isSafeId(ticketId)) return;
    final router = _router;
    if (router == null || !_session.isLoggedIn) {
      _pending = data; // se abrirá apenas la app (y la sesión) estén listas
      return;
    }
    if (_session.role != UserRole.worker) return;
    final userId = _session.user?.id;
    if (userId != null) _lastOpened = (data: data, userId: userId, at: DateTime.now());
    final notificationId = data['notificacionId']?.toString();
    if (notificationId != null) unawaited(_store.markRead(notificationId));
    router.go(Routes.workerTicketDetail(ticketId, focusComments: data['tipo'] == 'comentario'));
  }

  void dispose() {
    _session.removeListener(_onSessionChanged);
    for (final s in _subs) {
      s.cancel();
    }
  }
}
