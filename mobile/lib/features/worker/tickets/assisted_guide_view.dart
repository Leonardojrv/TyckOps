// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Asistencia de IA de diagnóstico" (T10 · mockup
//   colaborador/asistencia_ia_de_diagn_stico). Aparece en el detalle de un
//   ticket de prioridad Baja que sigue Recibido.
//
// ¿QUÉ HACE?
//   Muestra el ticket, la "Guía de solución IA" paso a paso y dos acciones:
//   - "Cerrar ticket (Problema solucionado)": se habilita solo después de
//     marcar "He completado la verificación guiada" (RF-11).
//   - "Reportar a administración": manda el ticket a la bandeja del
//     administrador como una falla real (RF-12).
//
// ¿CÓMO LO CAMBIO?
//   Los pasos vienen del servidor (GET /tickets/:id/guia). Los textos fijos y
//   los colores están aquí. El servidor revisa otra vez cada acción, así que
//   ocultar un botón aquí no basta para saltarse una regla.

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/self_help.dart';
import '../../../data/models/ticket.dart';
import '../worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

class AssistedGuideView extends StatefulWidget {
  const AssistedGuideView({
    super.key,
    required this.ticket,
    required this.loadGuide,
    required this.onResolve,
    required this.onDone,
  });

  final Ticket ticket;
  final Future<SelfHelpGuide> Function() loadGuide;

  /// Cierra o escala el ticket en el servidor (lo entrega MyTicketsStore).
  final Future<Ticket> Function(GuideAction action) onResolve;

  /// Se llama al terminar (bien o mal) con el mensaje para la persona.
  final Future<void> Function(String message) onDone;

  @override
  State<AssistedGuideView> createState() => _AssistedGuideViewState();
}

class _AssistedGuideViewState extends State<AssistedGuideView> {
  late Future<SelfHelpGuide> _guide = widget.loadGuide();
  bool _completed = false; // "He completado la verificación guiada"
  GuideAction? _busy; // qué botón está trabajando

  Future<void> _run(GuideAction action) async {
    setState(() => _busy = action);
    String message;
    try {
      await widget.onResolve(action);
      message = action == GuideAction.close
          ? '¡Listo! Cerraste la solicitud #${widget.ticket.code} como solucionada.'
          : 'Enviamos la solicitud #${widget.ticket.code} a Servicios Generales para su revisión.';
    } on ApiException catch (e) {
      message = e.message; // por ejemplo: el administrador ya la tomó (409)
    } catch (_) {
      message = 'No pudimos registrar tu decisión. Intenta nuevamente.';
    }
    if (!mounted) return;
    setState(() => _busy = null);
    await widget.onDone(message);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TicketCard(ticket: t),
        const SizedBox(height: 16),
        FutureBuilder<SelfHelpGuide>(
          future: _guide,
          builder: (context, snap) {
            if (snap.hasError) {
              return _GuideError(onRetry: () => setState(() => _guide = widget.loadGuide()));
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.primaryContainer)),
              );
            }
            return _GuideCard(guide: snap.data!);
          },
        ),
        const SizedBox(height: 16),
        _CompletedCheck(
          value: _completed,
          onChanged: _busy != null ? null : (v) => setState(() => _completed = v),
        ),
        const SizedBox(height: 20),
        _ActionButton(
          label: 'Cerrar ticket (Problema solucionado)',
          icon: Symbols.check_circle,
          background: _C.inverseSurface,
          busy: _busy == GuideAction.close,
          // Solo después de confirmar que hizo los pasos (mockup).
          onPressed: _completed && _busy == null ? () => _run(GuideAction.close) : null,
        ),
        const SizedBox(height: 12),
        _ActionButton(
          label: 'Reportar a administración',
          icon: Symbols.assignment_ind,
          background: _C.primaryContainer,
          busy: _busy == GuideAction.escalate,
          onPressed: _busy == null ? () => _run(GuideAction.escalate) : null,
        ),
      ],
    );
  }
}

// ===================== Tarjeta del ticket =====================

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return _AccentCard(
      accentHeight: 4,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('TICKET #${ticket.code}', style: _T.labelLg().copyWith(letterSpacing: 1.2)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.build, size: 13, color: _C.onSurface),
                    const SizedBox(width: 4),
                    Text('REPARACIÓN', style: _T.labelSm()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(999), boxShadow: workerShadowSm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.auto_awesome, size: 15, color: _C.primary, fill: 1),
                const SizedBox(width: 6),
                Text('Prioridad Baja', style: _T.labelSm().copyWith(fontWeight: FontWeight.w600)),
                Text('  ·  ', style: _T.labelSm(_C.secondary)),
                Text('Resolución Autónoma', style: _T.labelSm(_C.secondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(ticket.title, style: _T.headlineSm().copyWith(height: 1.25)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Symbols.apartment, size: 16, color: _C.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(ticket.location, style: _T.bodySm(_C.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================== Guía de solución IA =====================

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide});

  final SelfHelpGuide guide;

  @override
  Widget build(BuildContext context) {
    return _AccentCard(
      accentHeight: 3,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: _C.primaryFixed, shape: BoxShape.circle),
                      child: const Icon(Symbols.auto_awesome, size: 20, color: _C.primary, fill: 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(header: true, child: Text('Guía de solución IA', style: _T.headlineSm())),
                          const SizedBox(height: 2),
                          Text(
                            'Diagnóstico predictivo generado a partir del patrón de falla ingresado.',
                            style: _T.bodySm(_C.secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < guide.steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _StepRow(number: i + 1, step: guide.steps[i]),
                ],
              ],
            ),
          ),
          Container(
            color: _C.containerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Symbols.info, size: 18, color: _C.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Si el problema persiste tras seguir estos pasos, puedes escalar el ticket al administrador.',
                    style: _T.bodySm(_C.onSurfaceVariant).copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.step});

  final int number;
  final GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso $number: ${step.title}. ${step.detail}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: _C.containerHigh, shape: BoxShape.circle),
            child: Text('$number', style: _T.labelMd().copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: _T.labelLg()),
                if (step.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(step.detail, style: _T.bodySm(_C.secondary).copyWith(height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideError extends StatelessWidget {
  const _GuideError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _AccentCard(
      accentHeight: 3,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Symbols.cloud_off, size: 28, color: _C.secondary),
          const SizedBox(height: 8),
          Text('No pudimos cargar la guía', style: _T.labelLg()),
          const SizedBox(height: 4),
          Text(
            'Puedes reintentar o reportar el ticket a administración.',
            textAlign: TextAlign.center,
            style: _T.bodySm(_C.secondary),
          ),
          TextButton(onPressed: onRetry, child: Text('Reintentar', style: _T.labelLg(_C.primaryContainer))),
        ],
      ),
    );
  }
}

// ===================== Confirmación y botones =====================

class _CompletedCheck extends StatelessWidget {
  const _CompletedCheck({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.white,
      borderRadius: BorderRadius.circular(12),
      shadowColor: const Color(0x14000000),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
                  activeColor: _C.onSurface,
                  side: const BorderSide(color: _C.secondary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('He completado la verificación guiada', style: _T.labelMd()),
                    const SizedBox(height: 2),
                    Text('Seleccione la acción correspondiente para continuar', style: _T.caption(_C.secondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: _C.white,
          // Deshabilitado: el mismo color, más apagado (como el mockup).
          disabledBackgroundColor: background.withValues(alpha: busy ? 0.85 : 0.45),
          disabledForegroundColor: _C.white.withValues(alpha: 0.85),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _C.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: _C.white),
                  const SizedBox(width: 8),
                  Flexible(child: Text(label, style: _T.labelLg(_C.white), overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// Tarjeta blanca con la franja roja arriba (detalle "industrial" del mockup).
class _AccentCard extends StatelessWidget {
  const _AccentCard({required this.child, required this.accentHeight, required this.padding});

  final Widget child;
  final double accentHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: accentHeight, color: _C.primaryContainer),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
