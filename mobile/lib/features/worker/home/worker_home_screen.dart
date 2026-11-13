import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/ticket_time.dart';
import '../../../core/navigation/routes.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/ticket_status.dart';
import '../../auth/auth_session.dart';
import '../my_tickets_store.dart';
import '../worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

/// T5 · Home del colaborador (mockup colaborador/home_inicio).
class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key, required this.session, required this.store});

  final AuthSession session;
  final MyTicketsStore store;

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  static const _maxActiveShown = 3; // el mockup muestra las 3 más recientes

  @override
  void initState() {
    super.initState();
    widget.store.loadIfNeeded();
  }

  void _openTicket(Ticket ticket) {
    // Segunda barrera: un id raro nunca llega a la URL.
    if (!Ticket.isSafeId(ticket.id)) return;
    context.go(Routes.workerTicketDetail(ticket.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: _HomeHeader(onSignOut: widget.session.signOut),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final store = widget.store;
          final data = store.data;
          final user = widget.session.user;
          return RefreshIndicator(
            color: _C.primaryContainer,
            onRefresh: store.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _Greeting(name: user?.name ?? '', area: user?.area),
                const SizedBox(height: 8),
                _ReportCard(onCreate: () => context.go(Routes.workerReport)),
                const SizedBox(height: 24),
                _Metrics(data: data),
                const SizedBox(height: 24),
                _ActiveHeader(count: data?.inAttention),
                const SizedBox(height: 8),
                if (data != null)
                  _ActiveList(
                    tickets: data.active.take(_maxActiveShown).toList(),
                    onTap: _openTicket,
                  )
                else if (store.error != null)
                  _ErrorCard(message: store.error!, onRetry: store.load)
                else
                  const _LoadingCard(),
                const SizedBox(height: 8),
                _SeeAllButton(
                  total: data?.total,
                  onPressed: () => context.go(Routes.workerTickets),
                ),
                const SizedBox(height: 8),
                const _HelpDeskCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ===================== Encabezado =====================

class _HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const _HomeHeader({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  void _notificationsSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Las notificaciones estarán disponibles pronto.')));
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _C.surface.withValues(alpha: 0.9),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SERVICIOS GENERALES',
                        style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.55),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Inicio', style: _T.headlineSm().copyWith(height: 1.25), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () => _notificationsSoon(context),
                  constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                  icon: const Icon(Symbols.notifications, size: 24, color: _C.onSurface),
                ),
                const SizedBox(width: 4),
                _RoleChip(onSignOut: onSignOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip "Colaborador". Al tocarlo ofrece cerrar sesión (el mockup no tiene
/// otro lugar para hacerlo).
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Opciones de la cuenta',
      position: PopupMenuPosition.under,
      color: _C.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: onSignOut,
          child: Row(
            children: [
              const Icon(Symbols.logout, size: 20, color: _C.onSurface),
              const SizedBox(width: 12),
              Text('Cerrar sesión', style: _T.bodyMd()),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(999)),
        child: Text('Colaborador', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: -0.1)),
      ),
    );
  }
}

// ===================== Saludo =====================

/// El nombre viene del servidor según el correo con que se inició sesión:
/// Pedro Fernández → "Hola, Pedro Fernández". Si no hay nombre → "Hola".
String greetingFor(String? name) {
  final clean = name?.trim() ?? '';
  return clean.isEmpty ? 'Hola' : 'Hola, $clean';
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.area});

  final String name;
  final String? area;

  @override
  Widget build(BuildContext context) {
    final greeting = greetingFor(name);
    final details = [
      if (area != null && area!.trim().isNotEmpty) 'Área ${area!.trim()}',
      'Edificio Central Santiago',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PulsingDot(),
              const SizedBox(width: 6),
              Text('EDIFICIO CENTRAL · CHILE', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.55)),
            ],
          ),
          const SizedBox(height: 4),
          Text(greeting, style: _T.headlineLg().copyWith(letterSpacing: -0.6)),
          const SizedBox(height: 4),
          Text(details, style: _T.bodySm(_C.secondary)),
        ],
      ),
    );
  }
}

/// Punto rojo que "respira" (animate-pulse del mockup).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.5).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle),
      ),
    );
  }
}

// ===================== Tarjeta "Reportar una falla" =====================

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.inverseSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: workerShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _C.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.build_circle, fill: 1, size: 28, color: _C.inverseOnSurface),
          ),
          const SizedBox(height: 16),
          Text('Reportar una falla', style: _T.headlineSm(_C.inverseOnSurface)),
          const SizedBox(height: 4),
          Text(
            'Reporta problemas eléctricos, climatización HVAC, filtraciones o mantenimiento de mobiliario.',
            style: _T.bodySm(_C.secondaryFixed),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: _C.white,
                foregroundColor: _C.onSurface,
                overlayColor: _C.containerHighest,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Crear reporte', style: _T.labelLg()),
                  const SizedBox(width: 6),
                  const Icon(Symbols.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Métricas =====================

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data});

  final MyTickets? data;

  @override
  Widget build(BuildContext context) {
    final sla = data?.slaPercent;
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Symbols.assignment,
            value: data == null ? '—' : '${data!.inAttention}',
            label: 'EN ATENCIÓN',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            icon: Symbols.verified,
            value: sla == null ? '—' : '${sla.toStringAsFixed(1)}%',
            label: 'SLA CUMPLIDO',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: _C.onSurface),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: _T.headlineSm().copyWith(fontWeight: FontWeight.w700, height: 1.25)),
                Text(
                  label,
                  style: _T.caption(_C.secondary).copyWith(letterSpacing: -0.1),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Mis solicitudes activas =====================

class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text('Mis solicitudes activas', style: _T.headlineSm(), overflow: TextOverflow.ellipsis)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _C.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count en curso',
              style: _T.labelSm(_C.primaryContainer).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveList extends StatelessWidget {
  const _ActiveList({required this.tickets, required this.onTap});

  final List<Ticket> tickets;
  final ValueChanged<Ticket> onTap;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const _InfoCard(
        icon: Symbols.task_alt,
        text: 'No tienes solicitudes en curso. Si algo falla, crea un reporte.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < tickets.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _TicketCard(ticket: tickets[i], onTap: () => onTap(tickets[i])),
        ],
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  static Color _priorityColor(TicketPriority p) => switch (p) {
        TicketPriority.high => _C.primaryContainer,
        TicketPriority.medium => _C.error,
        TicketPriority.low => _C.secondary,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Solicitud ${ticket.code}, ${ticket.title}, ${ticket.status.label}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.transparent,
          highlightColor: _C.container.withValues(alpha: 0.6),
          child: Ink(
            padding: const EdgeInsets.all(16),
            // El fondo blanco va en el Ink: así la sombra queda debajo y no se ve gris.
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: workerShadowSm,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: _priorityColor(ticket.priority), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${ticket.code}',
                      style: _T.labelMd(_C.secondary).copyWith(
                        fontFamily: 'monospace',
                        fontFamilyFallback: const ['RobotoMono', 'Courier'],
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('·', style: _T.bodySm(_C.containerHighest)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(ticket.category, style: _T.caption(_C.secondary), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    _NeutralStatusChip(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.title,
                        style: _T.bodyMd().copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Symbols.chevron_right, size: 18, color: _C.secondary),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 1, color: _C.container),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Symbols.schedule, size: 15, color: _C.secondary),
                    const SizedBox(width: 4),
                    Text(formatTicketTime(ticket.createdAt), style: _T.bodySm(_C.secondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.location,
                        textAlign: TextAlign.right,
                        style: _T.caption(_C.secondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip neutro del mockup del colaborador: fondo gris y punto de color.
class _NeutralStatusChip extends StatelessWidget {
  const _NeutralStatusChip({required this.status});

  final TicketStatus status;

  static Color _dot(TicketStatus s) => switch (s) {
        TicketStatus.inProgress => _C.secondary,
        TicketStatus.inReview => _C.outline,
        TicketStatus.approved => _C.onSurface,
        TicketStatus.received => _C.containerHighest,
        TicketStatus.rejected => _C.error,
        _ => _C.secondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _C.secondaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: _dot(status), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status.label, style: _T.labelSm(_C.onSecondaryContainer)),
        ],
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.total, required this.onPressed});

  final int? total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _C.primaryContainer,
        overlayColor: _C.primaryContainer.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            total == null ? 'Ver todas mis solicitudes' : 'Ver todas mis solicitudes ($total)',
            style: _T.labelLg(_C.primaryContainer),
          ),
          const SizedBox(width: 6),
          const Icon(Symbols.arrow_forward, size: 18),
        ],
      ),
    );
  }
}

// ===================== Estados de carga y error =====================

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: _C.primaryContainer),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Symbols.cloud_off,
      text: message,
      action: TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(foregroundColor: _C.primaryContainer),
        child: Text('Reintentar', style: _T.labelLg(_C.primaryContainer)),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _C.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: _T.bodySm(_C.secondary))),
          ?action,
        ],
      ),
    );
  }
}

// ===================== Mesa de ayuda =====================

class _HelpDeskCard extends StatelessWidget {
  const _HelpDeskCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _C.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 1)],
            ),
            child: const Icon(Symbols.support_agent, size: 22, color: _C.primaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MESA DE AYUDA INTERNA', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.55)),
                const SizedBox(height: 2),
                Text(
                  'Horario atención Servicios Generales: Lun - Vie 08:30 a 18:00 hrs',
                  style: _T.bodySm().copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
