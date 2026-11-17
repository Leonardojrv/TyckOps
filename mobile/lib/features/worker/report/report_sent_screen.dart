import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/ticket_time.dart';
import '../../../core/navigation/routes.dart';
import '../../../data/models/ticket.dart';
import '../worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

/// T6 · Confirmación del reporte (mockup colaborador/confirmaci_n_ticket_reparaci_n).
class ReportSentScreen extends StatelessWidget {
  const ReportSentScreen({super.key, required this.ticket});

  final Ticket ticket;

  static IconData _categoryIcon(String category) {
    final c = category.toLowerCase();
    if (c.contains('eléctr') || c.contains('electr')) return Symbols.bolt;
    if (c.contains('baño') || c.contains('bano')) return Symbols.water_drop;
    if (c.contains('aire')) return Symbols.mode_fan;
    return Symbols.chair;
  }

  @override
  Widget build(BuildContext context) {
    void goHome() => context.go(Routes.workerHome);
    return PopScope(
      // El botón "atrás" de Android también vuelve al inicio (no al formulario vacío).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goHome();
      },
      child: Scaffold(
        backgroundColor: _C.surface,
        appBar: _Header(onBack: goHome),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const Center(child: _SuccessBadge()),
            const SizedBox(height: 16),
            Text(
              '¡Reporte registrado con éxito!',
              textAlign: TextAlign.center,
              style: _T.headlineLg().copyWith(letterSpacing: -0.6),
            ),
            const SizedBox(height: 4),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'El equipo de Mantenimiento e Infraestructura GA.MA ha recibido tu alerta.',
                  textAlign: TextAlign.center,
                  style: _T.bodyMd(_C.secondary).copyWith(height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _TicketCard(ticket: ticket, categoryIcon: _categoryIcon(ticket.category)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.containerHighest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: _C.white, shape: BoxShape.circle),
                    child: const Icon(Symbols.support_agent, size: 18, color: _C.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Un técnico evaluará la solicitud y te notificará ante cualquier actualización.',
                      style: _T.bodySm().copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ActionButton(
              label: 'Ver mi ticket',
              trailingIcon: Symbols.arrow_forward,
              primary: true,
              onPressed: () {
                if (Ticket.isSafeId(ticket.id)) context.go(Routes.workerTicketDetail(ticket.id));
              },
            ),
            const SizedBox(height: 8),
            _ActionButton(label: 'Volver al inicio', leadingIcon: Symbols.home, onPressed: goHome),
          ],
        ),
      ),
    );
  }
}

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
                  constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                  icon: const Icon(Symbols.arrow_back, size: 24, color: _C.onSurface),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Detalle De Solicitud', style: _T.headlineSm(), overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(999)),
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

/// Círculo rojo con check, halo que "late" y la insignia de herramienta.
class _SuccessBadge extends StatefulWidget {
  const _SuccessBadge();

  @override
  State<_SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<_SuccessBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ping =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Halo (animate-ping del mockup).
          AnimatedBuilder(
            animation: _ping,
            builder: (context, _) => Transform.scale(
              scale: 0.85 + 0.35 * _ping.value,
              child: Opacity(
                opacity: 0.75 * (1 - _ping.value),
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(color: _C.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                ),
              ),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: _C.primaryFixed.withValues(alpha: 0.6), shape: BoxShape.circle),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: _C.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)],
            ),
            child: const Icon(Symbols.check_circle, fill: 1, weight: 700, size: 42, color: _C.white),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: _C.inverseSurface,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 6, offset: Offset(0, 4))],
              ),
              child: const Icon(Symbols.build, size: 16, color: _C.surface),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.categoryIcon});

  final Ticket ticket;
  final IconData categoryIcon;

  @override
  Widget build(BuildContext context) {
    final registered = formatTicketTime(ticket.createdAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CÓDIGO DE INCIDENTE', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.55)),
                    Text(
                      '#${ticket.code}',
                      style: _T.headlineMd().copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: _C.containerHighest, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(ticket.status.label, style: _T.labelSm().copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: _C.container),
          const SizedBox(height: 16),
          _DetailRow(icon: categoryIcon, label: 'CATEGORÍA', value: Text(ticket.category, style: _value)),
          const SizedBox(height: 8),
          _DetailRow(icon: Symbols.location_on, label: 'UBICACIÓN', value: Text(ticket.location, style: _value)),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Symbols.schedule,
            label: 'PRIORIDAD ESTIMADA',
            value: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: _C.containerHighest, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                // Recién creado: la prioridad la asigna después la IA o el administrador.
                Text('Por asignar', style: _value.copyWith(fontWeight: FontWeight.w600)),
                Flexible(
                  child: Text(' · En evaluación', style: _T.bodySm(_C.secondary), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Registrado ${registered[0].toLowerCase()}${registered.substring(1)}',
                  style: _T.caption(_C.secondary),
                ),
              ),
              const Icon(Symbols.verified, size: 13, color: _C.secondary),
              const SizedBox(width: 4),
              Text('Registrado en GA.MA Ops', style: _T.caption(_C.secondary)),
            ],
          ),
        ],
      ),
    );
  }

  static TextStyle get _value => _T.bodyMd().copyWith(fontWeight: FontWeight.w500);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(label, style: _T.caption(_C.secondary).copyWith(letterSpacing: 0.5)),
                const SizedBox(height: 2),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? _C.white : _C.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: primary
            ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -1)]
            : const [],
      ),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: primary ? _C.primaryContainer : _C.container,
            foregroundColor: fg,
            overlayColor: primary ? _C.primary : _C.containerHigh,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[Icon(leadingIcon, size: 20), const SizedBox(width: 4)],
              Text(label, style: _T.labelLg(fg)),
              if (trailingIcon != null) ...[const SizedBox(width: 4), Icon(trailingIcon, size: 20)],
            ],
          ),
        ),
      ),
    );
  }
}
