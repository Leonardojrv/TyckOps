// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Notificaciones" del colaborador (T11 · mockup
//   colaborador/notificaciones_push). Se abre desde la campana del encabezado.
//
// ¿QUÉ HACE?
//   - Muestra la bandeja de avisos: cambios de estado y "Nuevo comentario en tu
//     ticket", agrupados por día (Hoy, Ayer, Esta semana, Anteriores).
//   - Los no leídos se destacan con fondo, franja y punto rojo.
//   - Tocar un aviso lo marca como leído y abre el ticket; si es un comentario,
//     el ticket se abre con los comentarios a la vista.
//   La notificación de la pantalla bloqueada NO se dibuja aquí: la muestra el
//   sistema (Android/iOS) y se configura en core/notifications/push_service.dart
//   y en el servidor (notificaciones.enviador.js).
//
// ¿CÓMO LO CAMBIO?
//   Íconos y etiquetas por tipo: _visualFor. Grupos por día: _sectionFor.
//   Los datos vienen de NotificationsStore (los comparte con la campana).

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
                  if (items.isNotEmpty) ...[
                    _FeedHeader(
                      unread: feed?.unread ?? 0,
                      onMarkAll: (feed?.unread ?? 0) > 0
                          ? store.markAllRead
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
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
                    const _EmptyState()
                  else
                    for (var i = 0; i < items.length; i++) ...[
                      // Título del día solo cuando cambia el grupo.
                      if (i == 0 ||
                          _sectionFor(items[i].createdAt) !=
                              _sectionFor(items[i - 1].createdAt))
                        _SectionLabel(
                          _sectionFor(items[i].createdAt),
                          first: i == 0,
                        )
                      else
                        const SizedBox(height: 10),
                      _NotificationCard(
                        notification: items[i],
                        onTap: () => _open(store, items[i]),
                      ),
                    ],
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

// ===================== Lista =====================

/// Fila superior: cuántas quedan sin leer y "Marcar todas leídas".
class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.unread, required this.onMarkAll});

  final int unread;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: unread > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _C.primaryFixed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unread == 1 ? '1 nueva' : '$unread nuevas',
                      style: _T
                          .labelSm(_C.onPrimaryFixed)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.done_all,
                        size: 16,
                        color: _C.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text('Estás al día', style: _T.labelMd(_C.secondary)),
                    ],
                  ),
          ),
        ),
        TextButton.icon(
          onPressed: onMarkAll,
          icon: const Icon(Symbols.done_all, size: 18),
          label: const Text('Marcar todas leídas', maxLines: 1),
          style: TextButton.styleFrom(
            foregroundColor: _C.primary,
            disabledForegroundColor: _C.secondary.withValues(alpha: 0.5),
            textStyle: _T.labelMd(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
          ),
        ),
      ],
    );
  }
}

/// Grupo de un aviso según su fecha: Hoy, Ayer, Esta semana o Anteriores.
String _sectionFor(DateTime date, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = today.difference(DateUtils.dateOnly(date)).inDays;
  if (days <= 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  if (days < 7) return 'Esta semana';
  return 'Anteriores';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.first});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 8 : 24, bottom: 10, left: 4),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: _T
              .caption(_C.secondary)
              .copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8),
        ),
      ),
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
    final unread = !n.read;
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label:
          '${unread ? 'No leída. ' : ''}Ticket ${n.ticketCode}. ${n.title}. ${n.body}. ${timeAgo(n.createdAt)}',
      excludeSemantics: true,
      child: Material(
        color: unread ? const Color(0xFFFFF7F6) : _C.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          highlightColor: _C.containerLow,
          splashColor: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: unread ? _C.primaryFixed : _C.container,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Franja roja a la izquierda: solo en las no leídas.
                  Container(
                    width: 3,
                    color: unread ? _C.primaryContainer : Colors.transparent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 14, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: v.tagBg,
                              shape: BoxShape.circle,
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
                                        unread ? _C.primary : _C.secondary,
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
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          v.tag,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: _T.labelSm(v.tagFg),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _T.bodyMd().copyWith(
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                                if (_detailLine(n).isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _detailLine(n),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: _T
                                        .bodySm(_C.secondary)
                                        .copyWith(height: 1.35),
                                  ),
                                ],
                                // La hora va abajo: así la etiqueta del estado
                                // no se corta en celulares angostos.
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
                            padding: const EdgeInsets.only(top: 14),
                            child: unread
                                ? Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: _C.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : const Icon(
                                    Symbols.chevron_right,
                                    size: 18,
                                    color: _C.containerHighest,
                                  ),
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

/// Bandeja vacía.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _C.container,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.notifications,
              size: 32,
              color: _C.secondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No tienes notificaciones',
            textAlign: TextAlign.center,
            style: _T.headlineSm(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Aquí verás los cambios de estado y los comentarios nuevos de tus solicitudes.',
              textAlign: TextAlign.center,
              style: _T.bodySm(_C.secondary).copyWith(height: 1.4),
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
