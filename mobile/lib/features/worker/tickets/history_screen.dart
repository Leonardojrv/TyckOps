// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Historial de Solicitudes" del colaborador (T9 · mockup
//   colaborador/historial_de_reparaciones).
//
// ¿QUÉ HACE?
//   Muestra tus tickets con un buscador (código, descripción o fecha) y tres
//   filtros: Rango de fechas, Tipo (categoría) y Estado. Arriba va la eficacia
//   (SLA) y abajo el total y el tiempo promedio de resolución. Al tocar un
//   ticket se abre su detalle.
//
// ¿CÓMO LO CAMBIO?
//   Las reglas de los filtros están en history_logic.dart. Los datos salen del
//   mismo MyTicketsStore que usan el home y "Mis Solicitudes": el servidor solo
//   entrega TUS tickets, así que aquí no se puede ver nada ajeno.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/ticket_time.dart';
import '../../../core/navigation/routes.dart';
import '../../../data/models/ticket.dart';
import '../my_tickets_store.dart';
import '../worker_tokens.dart';
import 'history_logic.dart';
import 'ticket_status_chip.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.store});

  final MyTicketsStore store;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  // Valores iniciales del mockup: "Últimos 30 días" y "Finalizados".
  HistoryRange _range = HistoryRange.last30;
  HistoryStatus _status = HistoryStatus.finished;
  String? _category; // null = Todos

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

  void _back() => context.go(Routes.workerTickets);

  void _open(Ticket t) {
    // Segunda barrera: un id raro nunca llega a la URL.
    if (Ticket.isSafeId(t.id)) context.go(Routes.workerTicketDetail(t.id));
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _range = HistoryRange.all;
      _status = HistoryStatus.all;
      _category = null;
    });
  }

  Future<void> _pickRange() async {
    final picked = await _showOptions<HistoryRange>(
      title: 'Rango de fechas',
      options: HistoryRange.values,
      selected: _range,
      label: (r) => r.label,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _pickStatus() async {
    final picked = await _showOptions<HistoryStatus>(
      title: 'Estado',
      options: HistoryStatus.values,
      selected: _status,
      label: (s) => s.label,
    );
    if (picked != null) setState(() => _status = picked);
  }

  Future<void> _pickCategory(List<String> categories) async {
    // '' representa "Todos" dentro de la lista de opciones.
    final picked = await _showOptions<String>(
      title: 'Tipo de solicitud',
      options: ['', ...categories],
      selected: _category ?? '',
      label: (c) => c.isEmpty ? 'Todos' : c,
    );
    if (picked != null) setState(() => _category = picked.isEmpty ? null : picked);
  }

  Future<T?> _showOptions<T>({
    required String title,
    required List<T> options,
    required T selected,
    required String Function(T) label,
  }) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true, // sobre la barra inferior también
      useSafeArea: true,
      backgroundColor: _C.white,
      barrierColor: _C.inverseSurface.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _OptionsSheet<T>(title: title, options: options, selected: selected, label: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: _HistoryHeader(onBack: _back),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final store = widget.store;
            final all = store.data?.tickets ?? const <Ticket>[];
            final categories = categoriesOf(all);
            // Si la categoría elegida ya no existe (por ejemplo, tras recargar), se vuelve a "Todos".
            final category = categories.contains(_category) ? _category : null;
            final visible = filterHistory(all, range: _range, status: _status, category: category, query: _search.text);
            final finished = all.where((t) => !t.isActive).toList();
            final average = averageResolution(all);

            return RefreshIndicator(
              color: _C.primaryContainer,
              onRefresh: store.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const _Intro(),
                  const SizedBox(height: 16),
                  _KpiCard(slaPercent: store.data?.slaPercent, average: average),
                  const SizedBox(height: 16),
                  _SearchBox(controller: _search),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _FilterPill(
                          icon: Symbols.calendar_today,
                          label: 'Rango',
                          value: _range.label,
                          onTap: _pickRange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FilterPill(
                          icon: Symbols.category,
                          label: 'Tipo',
                          value: category ?? 'Todos',
                          onTap: () => _pickCategory(categories),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FilterPill(
                    icon: Symbols.filter_alt,
                    label: 'Estado',
                    value: _status.label,
                    highlighted: true,
                    onTap: _pickStatus,
                  ),
                  const SizedBox(height: 16),
                  if (store.data == null && store.error != null)
                    _Message(
                      icon: Symbols.cloud_off,
                      title: 'No pudimos cargar tu historial',
                      text: store.error!,
                      actionLabel: 'Reintentar',
                      onAction: store.load,
                    )
                  else if (store.data == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.primaryContainer)),
                    )
                  else if (visible.isEmpty)
                    _Message(
                      icon: Symbols.search_off,
                      title: 'Sin resultados',
                      text: 'No se encontraron solicitudes que coincidan con la búsqueda o los filtros.',
                      actionLabel: 'Ver todo el historial',
                      onAction: _resetFilters,
                    )
                  else
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _HistoryCard(ticket: visible[i], onTap: () => _open(visible[i])),
                    ],
                  const SizedBox(height: 24),
                  _Footer(total: store.data == null ? null : finished.length, average: average),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===================== Encabezado =====================

class _HistoryHeader extends StatelessWidget implements PreferredSizeWidget {
  const _HistoryHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

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
            padding: const EdgeInsets.only(left: 4, right: 16),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Regresar',
                  onPressed: onBack,
                  icon: const Icon(Symbols.arrow_back, size: 24, color: _C.onSurface),
                ),
                const SizedBox(width: 4),
                Expanded(child: Text('Historial', style: _T.headlineSm(), overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(999)),
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

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('REGISTRO OPERATIVO GAMA', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.6)),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text('Historial de Solicitudes', style: _T.headlineLg())),
        const SizedBox(height: 4),
        Text(
          'Registro histórico de tickets resueltos, cerrados, rechazados y cancelados.',
          style: _T.bodyMd(_C.secondary),
        ),
      ],
    );
  }
}

// ===================== Eficacia (SLA) =====================

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.slaPercent, required this.average});

  final double? slaPercent; // null mientras el servidor no lo calcule
  final Duration? average;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Symbols.analytics, size: 22, color: _C.primaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EFICACIA OPERACIONAL', style: _T.caption(_C.secondary).copyWith(letterSpacing: 0.4)),
                Text(
                  slaPercent == null ? 'Sin datos de SLA todavía' : '${slaPercent!.toStringAsFixed(1)}% en SLA Objetivo',
                  style: _T.labelLg(),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (average != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _C.primaryFixed.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.speed, size: 14, color: _C.primaryContainer),
                  const SizedBox(width: 4),
                  Text('${formatAverage(average!).replaceAll(' hrs', 'h')} prom.', style: _T.labelSm(_C.primaryContainer)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== Buscador y filtros =====================

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
          hintText: 'Buscar por ID, descripción o fecha...',
          hintStyle: _T.bodyMd(_C.secondary),
          filled: true,
          fillColor: _C.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(Symbols.search, size: 20, color: _C.secondary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  onPressed: controller.clear,
                  icon: const Icon(Symbols.close, size: 18, color: _C.secondary),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.primaryContainer, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Botón redondo de filtro: "Rango: Últimos 30 días ⌄".
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool highlighted; // "Estado" va en gris y con el ícono rojo, como en el mockup

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Filtro $label: $value',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: highlighted ? _C.containerHigh : _C.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: workerShadowSm,
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: highlighted ? _C.primaryContainer : _C.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: _T.labelSm(),
                      children: [
                        TextSpan(text: '$label: '),
                        TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Symbols.expand_more, size: 16, color: highlighted ? _C.onSurface : _C.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja con las opciones de un filtro; la elegida lleva un check rojo.
class _OptionsSheet<T> extends StatelessWidget {
  const _OptionsSheet({required this.title, required this.options, required this.selected, required this.label});

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: _C.containerHighest, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: _T.headlineSm()),
          ),
          for (final option in options)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              selected: option == selected,
              selectedTileColor: _C.containerLow,
              title: Text(
                label(option),
                style: option == selected ? _T.labelLg() : _T.bodyMd(),
              ),
              trailing: option == selected ? const Icon(Symbols.check, size: 20, color: _C.primaryContainer) : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
  }
}

// ===================== Tarjeta del historial =====================

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final finished = isFinished(ticket);
    final date = formatTicketDate(historyDate(ticket));
    final dateText = finished ? 'Finalizado: $date' : 'Creado: $date';

    return Semantics(
      button: true,
      label: 'Solicitud ${ticket.code}, ${ticket.title}, ${ticket.status.label}, $dateText',
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
            decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('#${ticket.code}', style: _T.labelMd(_C.secondary)),
                              const SizedBox(width: 6),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(color: _C.containerHighest, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Flexible(child: _CategoryTag(category: ticket.category)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _T.headlineSm(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TicketStatusChip(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(finished ? Symbols.event_available : Symbols.calendar_today, size: 16, color: _C.secondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(dateText, style: _T.bodySm(_C.secondary), overflow: TextOverflow.ellipsis)),
                    Text('Detalle', style: _T.labelSm()),
                    const Icon(Symbols.chevron_right, size: 16, color: _C.onSurface),
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

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.build, size: 12, color: _C.secondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              category.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: _T.caption(_C.secondary).copyWith(letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Mensajes y pie =====================

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, required this.actionLabel, required this.onAction});

  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: _C.containerLow, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: _C.secondary),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: _T.headlineSm()),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: _T.bodySm(_C.secondary)),
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

class _Footer extends StatelessWidget {
  const _Footer({required this.total, required this.average});

  final int? total; // null mientras carga
  final Duration? average;

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, Color iconColor, String label, String value) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: _T.bodySm(_C.secondary),
                  children: [
                    TextSpan(text: '$label: '),
                    TextSpan(text: value, style: _T.labelMd()),
                  ],
                ),
              ),
            ),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Column(
        children: [
          line(Symbols.receipt_long, _C.onSurface, 'Total tickets históricos', total?.toString() ?? '—'),
          const SizedBox(height: 6),
          line(Symbols.timer, _C.primaryContainer, 'Tiempo promedio de resolución', average == null ? '—' : formatAverage(average!)),
        ],
      ),
    );
  }
}
