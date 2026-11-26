// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Listado de personal" del administrador (T13 · mockup
//   administrador/listado_de_personal).
//
// ¿QUÉ HACE?
//   Lista a las personas registradas con su área, rol, correo y una etiqueta de
//   sus tickets ("2 tickets abiertos", "1 ticket urgente"...). Tiene buscador
//   (nombre, área o correo), filtros por área con su cantidad y un filtro por
//   rol (botón de ajustes). Arriba resume cuántos colaboradores hay y cuántos
//   tienen tickets activos.
//
// ¿CÓMO LO CAMBIO?
//   Las reglas de búsqueda, filtros y etiquetas están en staff_logic.dart. Los
//   datos vienen del servidor (GET /api/admin/personal, solo administradores).
//   "Agregar trabajador" abrirá el formulario cuando exista su tarea.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/staff_member.dart';
import '../../../data/models/user_role.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../worker/tickets/ticket_status_chip.dart';
import '../../worker/worker_tokens.dart';
import '../admin_header.dart';
import 'staff_logic.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key, required this.repository, required this.onSignOut});

  final AdminRepository repository;
  final Future<void> Function() onSignOut; // chip "Administrador" del encabezado

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late Future<List<StaffMember>> _staff = widget.repository.staff();
  final _search = TextEditingController();
  String? _area; // null = Todos
  UserRole? _role; // null = todos los roles

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _staff = widget.repository.staff());
    await _staff.then((_) {}, onError: (_) {});
  }

  Future<void> _pickRole() async {
    FocusScope.of(context).unfocus();
    // La hoja responde ({role: ...}); null = la cerró sin elegir.
    final picked = await showModalBottomSheet<({UserRole? role})>(
      context: context,
      useRootNavigator: true,
      backgroundColor: _C.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _RoleSheet(selected: _role),
    );
    if (!mounted || picked == null) return;
    setState(() => _role = picked.role);
  }

  void _addWorker() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('El formulario para agregar trabajadores estará disponible pronto.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AdminHeader(
        title: 'Listado De Personal',
        onSignOut: widget.onSignOut,
        onBack: () => context.go(Routes.adminHome),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWorker,
        backgroundColor: _C.primaryContainer,
        foregroundColor: _C.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Symbols.person_add, size: 22),
        label: Text('+ Agregar trabajador', style: _T.labelLg(_C.white)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: FutureBuilder<List<StaffMember>>(
          future: _staff,
          builder: (context, snap) {
            final all = snap.data ?? const <StaffMember>[];
            final areas = areasOf(all);
            final area = areas.any((a) => a.area == _area) ? _area : null;
            final visible = filterStaff(all, area: area, role: _role, query: _search.text);
            final withTickets = all.where((p) => p.tickets.active > 0).length;

            return RefreshIndicator(
              color: _C.primaryContainer,
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Row(
                    children: [
                      Expanded(child: _SearchBox(controller: _search)),
                      const SizedBox(width: 8),
                      _FilterButton(active: _role != null, onTap: _pickRole),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AreaChips(
                    total: all.length,
                    areas: areas,
                    selected: area,
                    onSelected: (a) => setState(() => _area = a),
                  ),
                  const SizedBox(height: 16),
                  if (snap.hasError)
                    _Message(
                      icon: Symbols.cloud_off,
                      text: snap.error is ApiException
                          ? (snap.error! as ApiException).message
                          : 'No pudimos cargar el personal. Intenta nuevamente.',
                      onRetry: _reload,
                    )
                  else if (!snap.hasData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.primaryContainer)),
                    )
                  else ...[
                    _PulseBar(total: all.length, withTickets: withTickets),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      const _Message(icon: Symbols.person_search, text: 'No encontramos personas con esa búsqueda o filtro.')
                    else
                      for (var i = 0; i < visible.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _PersonCard(person: visible[i]),
                      ],
                  ],
                ],
              ),
            );
          },
        ),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: TextField(
        controller: controller,
        style: _T.bodyMd(),
        textInputAction: TextInputAction.search,
        cursorColor: _C.primaryContainer,
        maxLength: 60, // una búsqueda no necesita más
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Buscar trabajador por nombre, área o correo...',
          hintStyle: _T.bodyMd(_C.secondary),
          filled: true,
          fillColor: _C.containerLow,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          prefixIcon: const Icon(Symbols.search, size: 20, color: _C.secondary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  onPressed: controller.clear,
                  icon: const Icon(Symbols.close, size: 18, color: _C.secondary),
                ),
          // Sin borde (el tema general pone uno); solo el rojo al escribir.
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.primaryContainer, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active; // punto rojo cuando hay un filtro de rol puesto
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.container,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: const Color(0x14000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Symbols.tune, size: 20, color: _C.onSurface, semanticLabel: 'Filtrar por rol'),
              if (active)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSheet extends StatelessWidget {
  const _RoleSheet({required this.selected});

  final UserRole? selected;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, UserRole? role) {
      final isSelected = selected == role;
      return ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: _C.containerLow,
        title: Text(label, style: isSelected ? _T.labelLg() : _T.bodyMd()),
        trailing: isSelected ? const Icon(Symbols.check, size: 20, color: _C.primaryContainer) : null,
        onTap: () => Navigator.of(context).pop((role: role)),
      );
    }

    return SafeArea(
      child: Padding(
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
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Filtrar por rol', style: _T.headlineSm())),
            option('Todos los roles', null),
            option('Trabajador', UserRole.worker),
            option('Administrador', UserRole.admin),
          ],
        ),
      ),
    );
  }
}

/// Píldoras de área en grilla de 3 columnas (como el mockup). "Todos" lleva el total.
class _AreaChips extends StatelessWidget {
  const _AreaChips({required this.total, required this.areas, required this.selected, required this.onSelected});

  final int total;
  final List<({String area, int count})> areas;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _AreaChip(label: 'Todos', count: total, active: selected == null, onTap: () => onSelected(null)),
      for (final a in areas)
        _AreaChip(label: a.area, count: a.count, active: selected == a.area, onTap: () => onSelected(a.area)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - 12) / 3;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final chip in chips) SizedBox(width: width, child: chip)],
        );
      },
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({required this.label, required this.count, required this.active, required this.onTap});

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: '$label, $count personas',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? _C.primary : _C.containerLow,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active ? workerShadowSm : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: _T.labelSm(active ? _C.white : _C.secondary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: _C.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                  child: Text('$count', style: _T.caption(_C.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Resumen y tarjetas =====================

class _PulseBar extends StatelessWidget {
  const _PulseBar({required this.total, required this.withTickets});

  final int total;
  final int withTickets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Row(
        children: [
          const PulsingDot(color: _C.primaryContainer, size: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total ${total == 1 ? 'Colaborador' : 'Colaboradores'}',
                  overflow: TextOverflow.ellipsis,
                  style: _T.headlineSm(),
                ),
                Text('Sede Casa Matriz', style: _T.bodySm(_C.secondary)),
              ],
            ),
          ),
          if (withTickets > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _C.errorContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.warning, size: 16, color: _C.onErrorContainer, fill: 1),
                  const SizedBox(width: 4),
                  Text('$withTickets con tickets activos', style: _T.labelSm(_C.onErrorContainer)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final StaffMember person;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final badge = ticketBadge(p.tickets);
    final roleLabel = p.role == UserRole.admin ? 'Administrador' : 'Trabajador';
    return Semantics(
      label: '${p.name}, ${p.area ?? 'sin área'}, $roleLabel, ${p.email}, ${badge.text}',
      excludeSemantics: true,
      child: Container(
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
                      Text(p.name, overflow: TextOverflow.ellipsis, style: _T.headlineSm()),
                      Text(p.area ?? 'Sin área asignada', overflow: TextOverflow.ellipsis, style: _T.bodySm(_C.secondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(999)),
                  child: Text(roleLabel, style: _T.labelSm().copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Symbols.mail, size: 16, color: _C.secondary),
                const SizedBox(width: 4),
                Expanded(child: Text(p.email, overflow: TextOverflow.ellipsis, style: _T.bodySm(_C.secondary))),
                const SizedBox(width: 8),
                _TicketBadge(kind: badge.kind, text: badge.text),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketBadge extends StatelessWidget {
  const _TicketBadge({required this.kind, required this.text});

  final BadgeKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Widget lead) = switch (kind) {
      BadgeKind.urgent => (_C.errorContainer, _C.onErrorContainer, Text('!', style: _T.labelSm(_C.error).copyWith(fontWeight: FontWeight.w900))),
      BadgeKind.open => (
          _C.container,
          _C.onSurfaceVariant,
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle)),
        ),
      BadgeKind.inProgress => (_C.containerHigh, _C.onSurfaceVariant, const Icon(Symbols.autorenew, size: 13, color: _C.secondary)),
      BadgeKind.resolved => (_C.containerHigh, _C.onSurfaceVariant, const Icon(Symbols.check_circle, size: 13, color: Color(0xFF705300))),
      BadgeKind.none => (_C.containerLow, _C.secondary, const Icon(Symbols.check, size: 13, color: _C.secondary)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [lead, const SizedBox(width: 4), Text(text, style: _T.labelSm(fg).copyWith(fontWeight: FontWeight.w600))],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Column(
        children: [
          Icon(icon, size: 32, color: _C.secondary),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: _T.bodySm(_C.secondary)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text('Reintentar', style: _T.labelLg(_C.primaryContainer))),
        ],
      ),
    );
  }
}
