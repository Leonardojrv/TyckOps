// ¿PARA QUÉ SIRVE?
//   Es el Inicio del administrador (T13 · mockup administrador/inicio_del_administrador).
//
// ¿QUÉ HACE?
//   Saluda al administrador, muestra los números del día (tickets pendientes,
//   urgentes y duplicados) y las cinco opciones de gestión, cada una a su
//   pantalla: Generar ticket, Asignación de prioridad, Historial de
//   reparaciones, Listado de personal y Dashboard.
//   El chip "Administrador" del encabezado permite cerrar sesión.
//
// ¿CÓMO LO CAMBIO?
//   Las opciones están en la lista `modules` (título, subtítulo, etiquetas y
//   ruta). Los números vienen del servidor (GET /api/admin/resumen).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/routes.dart';
import '../../../data/models/staff_member.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../auth/auth_session.dart';
import '../../worker/tickets/ticket_status_chip.dart';
import '../../worker/worker_tokens.dart';
import '../admin_header.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

// Ámbar del mockup para "Tickets duplicados".
const _amber = Color(0xFFF9BD14); // tertiary-fixed-dim
const _amberText = Color(0xFF705300); // tertiary
const _green = Color(0xFF059669); // emerald-600 ("Operaciones activas")

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.session, required this.repository});

  final AuthSession session;
  final AdminRepository repository;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<AdminSummary> _summary = widget.repository.summary();

  Future<void> _reload() async {
    setState(() => _summary = widget.repository.summary());
    await _summary.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.session.user?.name ?? 'Administrador';
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AdminHeader(title: 'Inicio', onSignOut: widget.session.signOut),
      body: RefreshIndicator(
        color: _C.primaryContainer,
        onRefresh: _reload,
        child: FutureBuilder<AdminSummary>(
          future: _summary,
          builder: (context, snap) {
            // Si el resumen falla, el Home igual funciona (los números quedan en "—").
            final s = snap.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _Greeting(name: name),
                const SizedBox(height: 16),
                _StatsBar(summary: s, loading: snap.connectionState == ConnectionState.waiting),
                const SizedBox(height: 16),
                _ModulesHeader(count: _modules(s).length),
                const SizedBox(height: 12),
                for (final m in _modules(s)) ...[
                  _ModuleCard(module: m, onTap: () => context.go(m.route)),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Las cinco opciones del Home, cada una con su pantalla.
  List<_Module> _modules(AdminSummary? s) => [
        const _Module(
          icon: Symbols.add_circle,
          title: 'Generar ticket',
          subtitle: 'Solicitud directa de reparación de fallas',
          tags: [_Tag('Nuevo requerimiento')],
          route: Routes.adminNewTicket,
        ),
        const _Module(
          icon: Symbols.upload_file,
          title: 'Asignación de prioridad',
          subtitle: 'Carga .txt de autoayuda y prioridad Media/Alta',
          tags: [_Tag('Gestión IA')],
          route: Routes.adminPriority,
        ),
        _Module(
          icon: Symbols.home_repair_service,
          title: 'Historial de reparaciones',
          subtitle: 'Mantenciones, fallas e infraestructura',
          tags: [
            _Tag(s == null ? 'Tickets' : '${s.active} activos'),
            if ((s?.urgent ?? 0) > 0) _Tag('${s!.urgent} ${s.urgent == 1 ? 'Urgente' : 'Urgentes'}', urgent: true),
          ],
          route: Routes.adminHistory,
        ),
        _Module(
          icon: Symbols.badge,
          title: 'Listado de personal',
          subtitle: 'Colaboradores, áreas y asignaciones',
          tags: [_Tag(s == null ? 'Personal' : '${s.staff} ${s.staff == 1 ? 'trabajador' : 'trabajadores'}')],
          route: Routes.adminStaff,
        ),
        const _Module(
          icon: Symbols.query_stats,
          title: 'Dashboard',
          subtitle: 'Métricas, KPIs de SLA y Tendencias',
          live: true,
          tags: [_Tag('SLA')],
          route: Routes.adminDashboard,
        ),
      ];
}

// ===================== Saludo =====================

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Pill(text: 'ADMINISTRADOR', bg: _C.onSurface, fg: _C.white, spacing: 0.6),
            const SizedBox(width: 6),
            const _Pill(text: 'GA.MA CL', bg: _C.primaryContainer, fg: _C.white),
            const Spacer(),
            Material(
              color: _C.containerLow,
              shape: const CircleBorder(),
              elevation: 1,
              shadowColor: const Color(0x14000000),
              child: IconButton(
                tooltip: 'Notificaciones del sistema',
                onPressed: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Los avisos del administrador llegan con la bandeja de tickets.'))),
                icon: const Icon(Symbols.notifications, size: 20, color: _C.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Hola, $name', style: _T.headlineLg().copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Row(
          children: [
            const PulsingDot(color: _green, size: 8),
            const SizedBox(width: 6),
            // Un solo texto: en celulares angostos se acorta en vez de desbordarse.
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: _T.bodySm(_C.secondary),
                  children: [
                    TextSpan(text: 'Edificio Central', style: _T.bodySm(_C.onSurfaceVariant).copyWith(fontWeight: FontWeight.w500)),
                    const TextSpan(text: '  •  Operaciones Activas'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg, this.spacing = 0});

  final String text;
  final Color bg;
  final Color fg;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: _T.labelSm(fg).copyWith(fontWeight: FontWeight.w700, letterSpacing: spacing)),
    );
  }
}

// ===================== Números del día =====================

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.summary, required this.loading});

  final AdminSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String n(int Function(AdminSummary) pick) => summary == null ? (loading ? '…' : '—') : '${pick(summary!)}';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Stat(value: n((s) => s.pending), label: 'TICKETS PEND.')),
            const SizedBox(width: 6),
            Expanded(
              child: _Stat(
                value: n((s) => s.urgent),
                label: 'URGENTES',
                accent: _C.primaryContainer,
                icon: Symbols.error,
                valueColor: _C.primaryContainer,
                labelColor: _C.primary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Stat(
                value: n((s) => s.duplicates),
                label: 'TICKETS DUPLICADOS',
                accent: _amber,
                icon: Symbols.warning,
                valueColor: _amberText,
                labelColor: _amberText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.accent, this.icon, this.valueColor, this.labelColor});

  final String value;
  final String label;
  final Color? accent; // franja de color arriba
  final IconData? icon;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(8), boxShadow: workerShadowSm),
        child: Column(
          children: [
            Container(height: 4, color: accent ?? Colors.transparent),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[Icon(icon, size: 16, color: valueColor, fill: 1), const SizedBox(width: 2)],
                      Text(value, style: _T.headlineSm(valueColor ?? _C.onSurface).copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _T.labelSm(labelColor ?? _C.secondary).copyWith(fontWeight: accent == null ? FontWeight.w500 : FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Módulos =====================

class _ModulesHeader extends StatelessWidget {
  const _ModulesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Text('MÓDULOS DE GESTIÓN', style: _T.labelSm(_C.secondary).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.6)),
          ),
          Text('$count Secciones', style: _T.labelSm(_C.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Tag {
  const _Tag(this.text, {this.urgent = false});

  final String text;
  final bool urgent;
}

class _Module {
  const _Module({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.tags = const [],
    this.live = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final List<_Tag> tags;
  final bool live; // chip "En tiempo real" del Dashboard
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});

  final _Module module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = module;
    return Semantics(
      button: true,
      label: '${m.title}. ${m.subtitle}',
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
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(12)),
                  child: Icon(m.icon, size: 26, color: _C.onSurface),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(m.title, overflow: TextOverflow.ellipsis, style: _T.headlineSm())),
                          if (m.live) ...[const SizedBox(width: 8), const _LiveChip()],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(m.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _T.bodySm(_C.secondary)),
                      if (m.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final t in m.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: t.urgent ? _C.primaryFixed : _C.container,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  t.text,
                                  style: _T.labelSm(t.urgent ? _C.primary : _C.onSurface).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Symbols.chevron_right, size: 22, color: _C.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: _C.primaryFixed, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PulsingDot(color: _C.primaryContainer, size: 6),
          const SizedBox(width: 4),
          Text('En tiempo real', style: _T.labelSm(_C.primary).copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
