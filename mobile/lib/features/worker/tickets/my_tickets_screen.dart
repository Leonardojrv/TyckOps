// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Mis Solicitudes" (T7).
//
// ¿QUÉ HACE?
//   Lista todos tus tickets con buscador y filtros (Todos, En curso, Rechazado,
//   Resuelto) y abre el detalle al tocar uno. Abajo tiene el acceso al
//   Historial con filtros por fecha y estado (T9).
//
// ¿CÓMO LO CAMBIO?
//   Las reglas de los filtros y la búsqueda están en ticket_logic.dart.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/ticket_time.dart';
import '../../../core/navigation/routes.dart';
import '../../../data/models/ticket.dart';
import '../../auth/auth_session.dart';
import '../my_tickets_store.dart';
import '../worker_header.dart';
import '../worker_tokens.dart';
import 'ticket_logic.dart';
import 'ticket_status_chip.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

/// T7 · "Mis Solicitudes": todos los tickets del colaborador, con buscador y
/// filtros por estado (mockup colaborador/mis_solicitudes_listado).
///
/// Los datos salen del mismo [MyTicketsStore] que usa el home, así que si
/// aquí se recarga, el home y el contador de la barra también se actualizan.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key, required this.session, required this.store});

  final AuthSession session;
  final MyTicketsStore store;

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final _search = TextEditingController();
  TicketFilter _filter = TicketFilter.all;

  @override
  void initState() {
    super.initState();
    widget.store.loadIfNeeded();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Ticket t) {
    // Segunda barrera: un id raro nunca llega a la URL.
    if (Ticket.isSafeId(t.id)) context.go(Routes.workerTicketDetail(t.id));
  }

  void _resetFilters() {
    _search.clear();
    setState(() => _filter = TicketFilter.all);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: WorkerHeader(title: 'Mis Solicitudes', onSignOut: widget.session.signOut),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final store = widget.store;
            final all = store.data?.tickets ?? const <Ticket>[];
            final visible = filterTickets(all, _filter, _search.text);
            return RefreshIndicator(
              color: _C.primaryContainer,
              onRefresh: store.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _Title(total: store.data == null ? null : all.length),
                  const SizedBox(height: 8),
                  _SearchBox(controller: _search),
                  const SizedBox(height: 12),
                  _FilterGrid(
                    selected: _filter,
                    counts: {for (final f in TicketFilter.values) f: all.where(f.matches).length},
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                  const SizedBox(height: 12),
                  if (store.data == null && store.error != null)
                    _Message(
                      icon: Symbols.cloud_off,
                      title: 'No pudimos cargar tus solicitudes',
                      text: store.error!,
                      actionLabel: 'Reintentar',
                      onAction: store.load,
                    )
                  else if (store.data == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.primaryContainer)),
                    )
                  else if (all.isEmpty)
                    _Message(
                      icon: Symbols.inbox,
                      title: 'Aún no tienes solicitudes',
                      text: 'Cuando reportes una falla, aparecerá aquí con su estado.',
                      actionLabel: 'Reportar una falla',
                      onAction: () => context.go(Routes.workerReport),
                    )
                  else if (visible.isEmpty)
                    _Message(
                      icon: Symbols.search_off,
                      title: 'Sin solicitudes coincidentes',
                      text: 'No se hallaron tickets bajo este filtro o término de búsqueda.',
                      actionLabel: 'Restablecer filtros',
                      onAction: _resetFilters,
                    )
                  else
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _TicketCard(ticket: visible[i], onTap: () => _open(visible[i])),
                    ],
                  const SizedBox(height: 24),
                  _HistoryLink(onTap: () => context.go(Routes.workerHistory)),
                  const SizedBox(height: 12),
                  _NewReportBanner(onPressed: () => context.go(Routes.workerReport)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===================== Título y buscador =====================

class _Title extends StatelessWidget {
  const _Title({required this.total});

  final int? total; // null mientras carga

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PANEL TÉCNICO', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.55)),
              Text('Mis Solicitudes', style: _T.headlineLg().copyWith(letterSpacing: -0.6)),
            ],
          ),
        ),
        if (total != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulsingDot(color: _C.primaryContainer, size: 8),
                const SizedBox(width: 6),
                Text('$total ${total == 1 ? 'registrada' : 'registradas'}', style: _T.labelSm()),
              ],
            ),
          ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: workerShadowSm),
      child: TextField(
        controller: controller,
        style: _T.bodyMd(),
        textInputAction: TextInputAction.search,
        cursorColor: _C.primaryContainer,
        maxLength: 60, // una búsqueda no necesita más
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Buscar por código, sala, insumo...',
          hintStyle: _T.bodyMd(_C.secondary),
          filled: true,
          fillColor: _C.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(Symbols.search, size: 20, color: _C.secondary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  onPressed: controller.clear,
                  icon: const Icon(Symbols.close, size: 18, color: _C.secondary),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.primaryContainer, width: 2),
          ),
        ),
      ),
    );
  }
}

// ===================== Filtros =====================

class _FilterGrid extends StatelessWidget {
  const _FilterGrid({required this.selected, required this.counts, required this.onSelected});

  final TicketFilter selected;
  final Map<TicketFilter, int> counts;
  final ValueChanged<TicketFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = TicketFilter.values;
    Widget chip(TicketFilter f) {
      final active = f == selected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          child: GestureDetector(
            onTap: () => onSelected(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _C.onSurface : _C.containerHigh,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active ? workerShadowSm : const [],
              ),
              child: Text('${f.label} (${counts[f] ?? 0})', style: _T.labelSm(active ? _C.surface : _C.onSurface)),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [chip(filters[0]), const SizedBox(width: 8), chip(filters[1])]),
        const SizedBox(height: 8),
        Row(children: [chip(filters[2]), const SizedBox(width: 8), chip(filters[3])]),
      ],
    );
  }
}

// ===================== Tarjeta de ticket =====================

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

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
            decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Symbols.build, size: 17, color: _C.onSurface),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '#${ticket.code}',
                      style: _T.labelMd(_C.secondary).copyWith(fontFamily: 'monospace', letterSpacing: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text('·', style: _T.caption(_C.secondary.withValues(alpha: 0.4))),
                    const SizedBox(width: 4),
                    Expanded(child: Text(ticket.category, style: _T.bodySm(_C.secondary), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    TicketStatusChip(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _T.headlineSm().copyWith(height: 1.375),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Symbols.schedule, size: 14, color: _C.secondary),
                              const SizedBox(width: 6),
                              Text(formatTicketTime(ticket.createdAt).replaceAll(' hrs', ''), style: _T.bodySm(_C.secondary)),
                              const SizedBox(width: 6),
                              Text('·', style: _T.bodySm(_C.secondary.withValues(alpha: 0.4))),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(ticket.location, style: _T.bodySm(_C.secondary), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(color: _C.containerLow, shape: BoxShape.circle, boxShadow: workerShadowSm),
                      child: const Icon(Symbols.arrow_forward, size: 18, color: _C.secondary),
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

// ===================== Mensajes y banner =====================

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, required this.actionLabel, required this.onAction});

  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: _C.containerHigh, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: _C.secondary),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: _T.headlineSm()),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(text, textAlign: TextAlign.center, style: _T.bodySm(_C.secondary)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: _C.containerHighest,
                foregroundColor: _C.onSurface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(actionLabel, style: _T.labelSm().copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// T9 · Acceso al historial con filtros por fecha y estado.
class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver historial de solicitudes',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Symbols.history, size: 22, color: _C.primaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Historial de solicitudes', style: _T.labelLg()),
                      Text('Busca por fecha, estado o tipo', style: _T.bodySm(_C.secondary)),
                    ],
                  ),
                ),
                const Icon(Symbols.chevron_right, size: 20, color: _C.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewReportBanner extends StatelessWidget {
  const _NewReportBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _C.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Symbols.add_circle, size: 20, color: _C.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Necesitas algo más?', style: _T.labelLg()),
                Text('Crea un reporte de falla', style: _T.bodySm(_C.secondary)),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _C.onSurface,
                foregroundColor: _C.surface,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Nueva', style: _T.labelSm(_C.surface).copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
