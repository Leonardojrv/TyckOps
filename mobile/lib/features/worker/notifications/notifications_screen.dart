// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Notificaciones" del colaborador (T11 · mockup
//   colaborador/notificaciones_push). Se abre desde la campana del encabezado.
//
// ¿QUÉ HACE?
//   - Arriba, "Previsualización del sistema push": cómo se ve en el celular el
//     aviso más reciente (al tocarlo, abre su ticket).
//   - Abajo, la lista de avisos: cambios de estado y "Nuevo comentario en tu
//     ticket", cada uno con su número de ticket. Los no leídos llevan el punto rojo.
//   - Tocar un aviso lo marca como leído y abre el ticket; si es un comentario,
//     el ticket se abre con los comentarios a la vista.
//
// ¿CÓMO LO CAMBIO?
//   Íconos y etiquetas por tipo: _visualFor. Los datos vienen de
//   NotificationsStore (los comparte con la campana).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/routes.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/ticket_status.dart';
import '../worker_tokens.dart';
import 'notifications_store.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Al abrir la pantalla se piden los avisos más recientes (una vez).
    if (!_requested) {
      _requested = true;
      final store = NotificationsScope.maybeOf(context);
      // Después del primer dibujo: pedirlos durante el dibujo no está permitido.
      WidgetsBinding.instance.addPostFrameCallback((_) => store?.load());
    }
  }

  void _open(NotificationsStore store, AppNotification n) {
    store.markRead(n.id);
    // Segunda barrera: un id raro nunca llega a la URL.
    if (!Ticket.isSafeId(n.ticketId)) return;
    context.go(
      Routes.workerTicketDetail(
        n.ticketId,
        focusComments: n.type == NotificationType.comment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = NotificationsScope.maybeOf(context);
    final feed = store?.feed;
    final items = feed?.items ?? const <AppNotification>[];

    return Scaffold(
      backgroundColor: _C.surface,
      appBar: _Header(onBack: () => context.go(Routes.workerHome)),
      body: store == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              color: _C.primaryContainer,
              onRefresh: store.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _PushPreview(
                    latest: items.firstOrNull,
                    onTap: items.isEmpty
                        ? null
                        : () => _open(store, items.first),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: _C.containerHighest),
                  const SizedBox(height: 24),
                  _FeedHeader(
                    unread: feed?.unread ?? 0,
                    onMarkAll: (feed?.unread ?? 0) > 0
                        ? store.markAllRead
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (feed == null && store.error != null)
                    _Message(
                      icon: Symbols.cloud_off,
                      title: 'No pudimos cargar tus notificaciones',
                      text: store.error!,
                      onRetry: store.load,
                    )
                  else if (feed == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _C.primaryContainer,
                        ),
                      ),
                    )
                  else if (items.isEmpty)
                    const _Message(
                      icon: Symbols.notifications_off,
                      title: 'Aún no tienes notificaciones',
                      text: 'Te avisaremos aquí cuando tus solicitudes cambien de estado o tengan un comentario nuevo.',
                    )
                  else
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _NotificationCard(
                        notification: items[i],
                        onTap: () => _open(store, items[i]),
                      ),
                    ],
                  const SizedBox(height: 24),
                  const _TapHint(),
                ],
              ),
            ),
    );
  }
}

// ===================== Encabezado =====================

class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _C.surface.withValues(alpha: 0.9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 16),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Regresar',
                  onPressed: onBack,
                  icon: const Icon(
                    Symbols.arrow_back,
                    size: 24,
                    color: _C.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Notificaciones',
                    style: _T.headlineSm(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _C.container,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Colaborador', style: _T.labelSm(_C.secondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== Previsualización del push =====================

const _weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _months = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Imita la pantalla de bloqueo del celular con el aviso más reciente.
class _PushPreview extends StatelessWidget {
  const _PushPreview({required this.latest, required this.onTap});

  final AppNotification? latest;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final date =
        '${_weekdays[now.weekday - 1]}, ${now.day} de ${_months[now.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _C.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'PREVISUALIZACIÓN DEL SISTEMA PUSH',
                overflow: TextOverflow.ellipsis,
                style: _T.caption(_C.secondary).copyWith(letterSpacing: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
            gradient: const RadialGradient(
              center: Alignment(1.1, -1.2),
              radius: 1.2,
              colors: [Color(0xFF5A2A2C), _C.inverseSurface],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Symbols.lock, size: 14, color: Color(0xFFC8C6C5)),
                  const SizedBox(width: 4),
                  Text(
                    'Santiago de Chile',
                    style: _T.labelSm(const Color(0xFFC8C6C5)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: _T
                    .headlineLg(_C.white)
                    .copyWith(
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(date, style: _T.labelMd(const Color(0xFFC8C6C5))),
              const SizedBox(height: 16),
              _Banner(notification: latest, onTap: onTap),
              const SizedBox(height: 16),
              Container(
                width: 96,
                height: 4,
                decoration: BoxDecoration(
                  color: _C.containerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.notification, required this.onTap});

  final AppNotification? notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final heading = n == null
        ? 'Sin avisos todavía'
        : n.type == NotificationType.comment
        ? 'Nuevo comentario en tu ticket'
        : 'Actualización de Estado';
    return Material(
      color: _C.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _C.inverseSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'G',
                            style: _T
                                .caption(_C.white)
                                .copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          TextSpan(
                            text: '.',
                            style: _T
                                .caption(_C.primaryContainer)
                                .copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SERVICIOS GENERALES GAMA',
                      overflow: TextOverflow.ellipsis,
                      style: _T.caption().copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (n != null)
                    Text(
                      timeAgo(n.createdAt).toLowerCase(),
                      style: _T.caption(_C.secondary),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: _C.container),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _C.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      heading,
                      overflow: TextOverflow.ellipsis,
                      style: _T.labelSm().copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                n?.body ?? 'Cuando tus solicitudes cambien de estado, el aviso se verá así en tu celular.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _T.bodySm(_C.secondary).copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Lista =====================

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.unread, required this.onMarkAll});

  final int unread;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Título y contador usan solo el ancho que necesitan; si el celular es
        // muy angosto, el título se acorta antes que esconder el botón.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text('Notificaciones', style: _T.headlineMd(), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _C.primaryFixed, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    unread == 1 ? '1 nueva' : '$unread nuevas',
                    style: _T.labelSm(_C.onPrimaryFixed).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: onMarkAll,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 36)),
          child: Text(
            'Marcar todas leídas',
            maxLines: 1,
            style: _T.labelMd(onMarkAll == null ? _C.secondary.withValues(alpha: 0.5) : _C.primary),
          ),
        ),
      ],
    );
  }
}

/// Ícono, color y etiqueta de cada aviso (como el mockup).
({IconData icon, Color iconColor, String tag, Color tagBg, Color tagFg})
_visualFor(AppNotification n) {
  if (n.type == NotificationType.comment) {
    return (
      icon: Symbols.chat_bubble,
      iconColor: _C.secondary,
      tag: 'Nota Admin',
      tagBg: _C.containerHigh,
      tagFg: _C.onSurface,
    );
  }
  final status = n.status;
  return switch (status) {
    TicketStatus.inProgress => (
      icon: Symbols.engineering,
      iconColor: _C.primary,
      tag: status!.label,
      tagBg: _C.containerHigh,
      tagFg: _C.onSurface,
    ),
    TicketStatus.rejected => (
      icon: Symbols.cancel,
      iconColor: _C.error,
      tag: status!.label,
      tagBg: _C.errorContainer,
      tagFg: _C.onErrorContainer,
    ),
    TicketStatus.resolved => (
      icon: Symbols.task_alt,
      iconColor: _C.secondary,
      tag: status!.label,
      tagBg: _C.containerHigh,
      tagFg: _C.onSurface,
    ),
    TicketStatus.closed => (
      icon: Symbols.lock,
      iconColor: _C.secondary,
      tag: status!.label,
      tagBg: _C.containerHigh,
      tagFg: _C.onSurface,
    ),
    TicketStatus.approved => (
      icon: Symbols.verified,
      iconColor: _C.secondary,
      tag: status!.label,
      tagBg: _C.containerHigh,
      tagFg: _C.onSurface,
    ),
    TicketStatus.inReview => (
      icon: Symbols.manage_search,
      iconColor: _C.secondary,
      tag: status!.label,
      tagBg: _C.containerHigh,
      tagFg: _C.onSurface,
    ),
    _ => (
      icon: Symbols.notifications,
      iconColor: _C.secondary,
      tag: status?.label ?? 'Aviso',
      tagBg: _C.containerHigh,
      tagFg: _C.onSurface,
    ),
  };
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final v = _visualFor(n);
    return Semantics(
      button: true,
      label:
          '${n.read ? '' : 'No leída. '}Ticket ${n.ticketCode}. ${n.title}. ${n.body}. ${timeAgo(n.createdAt)}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.transparent,
          highlightColor: _C.containerLow,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: workerShadowSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _C.container,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(v.icon, size: 20, color: v.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${n.ticketCode}',
                            style: _T.labelMd(
                              n.read ? _C.secondary : _C.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: v.tagBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                v.tag,
                                overflow: TextOverflow.ellipsis,
                                style: _T.labelSm(v.tagFg),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _T.bodyMd().copyWith(
                          fontWeight: n.read
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _detailLine(n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _T.bodySm(_C.secondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timeAgo(n.createdAt),
                        style: _T.caption(_C.secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: n.read
                      ? const Icon(
                          Symbols.chevron_right,
                          size: 18,
                          color: _C.containerHighest,
                        )
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _C.primaryContainer,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _C.primaryFixed.withValues(alpha: 0.6),
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segunda línea de la tarjeta: sin repetir el número del ticket.
String _detailLine(AppNotification n) => n.body
    .replaceFirst(RegExp('^#${RegExp.escape(n.ticketCode)}:\\s*'), '')
    .replaceFirst(
      RegExp(
        '^Tu ticket #${RegExp.escape(n.ticketCode)} cambió a "[^"]*"\\.\\s*',
      ),
      '',
    );

class _TapHint extends StatelessWidget {
  const _TapHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.containerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: _C.containerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.touch_app, size: 18, color: _C.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Toca cualquier notificación para abrir el detalle del ticket.',
              style: _T.bodySm(_C.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: workerShadowSm,
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: _C.secondary),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: _T.labelLg()),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: _T.bodySm(_C.secondary),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('Reintentar', style: _T.labelLg(_C.primaryContainer)),
            ),
        ],
      ),
    );
  }
}

/// "Hace 5 min" · "Hace 3 h" · "Ayer" · "Hace 3 días".
String timeAgo(DateTime date, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(date);
  if (d.inMinutes < 1) return 'Ahora';
  if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'Hace ${d.inHours} h';
  if (d.inDays == 1) return 'Ayer';
  return 'Hace ${d.inDays} días';
}
