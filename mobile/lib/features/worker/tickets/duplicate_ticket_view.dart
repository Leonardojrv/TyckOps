// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Ticket duplicado · Mensaje al colaborador" (T10 · mockup
//   colaborador/ticket_duplicado_mensaje_al_colaborador). Solo aparece en los
//   tickets que la IA agrupó con otro que ya se estaba atendiendo.
//
// ¿QUÉ HACE?
//   Explica que la falla ya estaba reportada, muestra la solicitud ORIGINAL
//   (código, falla, fecha, ubicación y estado, sin decir quién la reportó) y
//   ofrece "Ver solicitud original" (su avance) y "Volver al inicio".
//
// ¿CÓMO LO CAMBIO?
//   Los textos están aquí. El texto de "Estado operativo" de cada estado está
//   en _operationalStatus. Los datos los manda el servidor en el detalle
//   (campo duplicateOf).

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/ticket_time.dart';
import '../../../data/models/fault_category.dart';
import '../../../data/models/self_help.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/ticket_status.dart';
import '../worker_tokens.dart';
import 'ticket_logic.dart';
import 'ticket_status_chip.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

class DuplicateTicketView extends StatelessWidget {
  const DuplicateTicketView({super.key, required this.ticket, required this.original, required this.onGoHome});

  final Ticket ticket; // el tuyo (el agrupado)
  final DuplicateOriginal original;
  final VoidCallback onGoHome;

  void _showOriginal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: _C.white,
      barrierColor: _C.inverseSurface.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _OriginalProgressSheet(original: original),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _Header(mine: original.mine),
        const SizedBox(height: 24),
        _OriginalCard(ticket: ticket, original: original),
        const SizedBox(height: 16),
        const _ThanksCard(),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => _showOriginal(context),
            style: FilledButton.styleFrom(
              backgroundColor: _C.primaryContainer,
              foregroundColor: _C.white,
              overlayColor: _C.primary,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.visibility, size: 20, color: _C.white),
                const SizedBox(width: 8),
                Text('Ver solicitud original', style: _T.labelLg(_C.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: onGoHome,
            style: FilledButton.styleFrom(
              backgroundColor: _C.containerHigh,
              foregroundColor: _C.onSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.arrow_back, size: 20, color: _C.onSurface),
                const SizedBox(width: 8),
                Text('Volver al inicio', style: _T.labelLg()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===================== Encabezado =====================

class _Header extends StatelessWidget {
  const _Header({required this.mine});

  final bool mine; // el original también es tuyo: cambia el mensaje

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: _C.containerHigh, shape: BoxShape.circle),
          child: const Icon(Symbols.content_copy, size: 30, color: _C.onSurface),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.layers, size: 14, color: _C.secondary),
              const SizedBox(width: 6),
              Text('AVISO DE TICKET AGRUPADO', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.6)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text('Tu solicitud ya fue registrada', textAlign: TextAlign.center, style: _T.headlineLg()),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            mine
                ? 'Ya habías reportado esta misma falla y nuestro equipo ya está atendiéndola. '
                    'Por eso agrupamos tu nuevo ticket con el original.'
                : 'El requerimiento que solicitaste ya fue ingresado por otro colaborador y nuestro equipo ya está '
                    'atendiéndolo. Por eso agrupamos tu ticket con el original.',
            textAlign: TextAlign.center,
            style: _T.bodyMd(_C.secondary).copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

// ===================== Solicitud original =====================

class _OriginalCard extends StatelessWidget {
  const _OriginalCard({required this.ticket, required this.original});

  final Ticket ticket;
  final DuplicateOriginal original;

  @override
  Widget build(BuildContext context) {
    final category = categoryFor(original.category);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: _C.containerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Symbols.hub, size: 18, color: _C.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    original.mine ? 'TU SOLICITUD ORIGINAL' : 'SOLICITUD ORIGINAL',
                    style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.6),
                  ),
                ),
                TicketStatusChip(status: original.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#${original.code}', style: _T.headlineMd()),
                    const SizedBox(width: 12),
                    // La categoría ocupa el resto y queda pegada a la derecha (mockup).
                    Expanded(
                      child: Text(
                        category?.headline ?? original.category,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: _T.labelMd(_C.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(8)),
                        child: Icon(category?.icon ?? Symbols.build, size: 20, color: _C.onSurface),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          original.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _T.headlineSm().copyWith(fontSize: 16, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Symbols.schedule,
                  label: 'FECHA DE INGRESO',
                  value: formatTicketTime(original.createdAt),
                  extra: ' (${timeAgo(original.createdAt)})',
                ),
                const SizedBox(height: 12),
                _InfoRow(icon: Symbols.location_on, label: 'UBICACIÓN FÍSICA', value: original.location),
                const SizedBox(height: 12),
                _InfoRow(icon: Symbols.engineering, label: 'ESTADO OPERATIVO', value: operationalStatus(original.status)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Symbols.link, size: 18, color: _C.primaryContainer),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: _T.bodySm().copyWith(height: 1.4),
                            children: [
                              const TextSpan(text: 'Tu ticket '),
                              TextSpan(
                                text: '#${ticket.code}',
                                style: _T.bodySm(_C.primaryContainer).copyWith(fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(
                                text: ' ha sido unificado a este caso para recibir actualizaciones conjuntas en tiempo real.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.extra});

  final IconData icon;
  final String label;
  final String value;
  final String? extra; // texto gris al final, por ejemplo "(hace 45 min)"

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: _C.secondary)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _T.caption(_C.secondary).copyWith(letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  style: _T.labelMd(),
                  children: [
                    TextSpan(text: value),
                    if (extra != null) TextSpan(text: extra, style: _T.labelMd(_C.secondary).copyWith(fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThanksCard extends StatelessWidget {
  const _ThanksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: _C.containerHighest, shape: BoxShape.circle),
            child: const Icon(Symbols.handshake, size: 20, color: _C.secondary, fill: 1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¡Gracias por tu colaboración activa!', style: _T.labelMd()),
                const SizedBox(height: 2),
                Text(
                  'Tu aviso nos ayuda a mantener las instalaciones operativas. Que tengas una excelente jornada.',
                  style: _T.bodySm(_C.secondary).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== "Ver solicitud original" =====================

/// Hoja con el avance de la solicitud original (la línea de tiempo del estado).
/// Solo se ve el estado: nunca quién la reportó ni sus fotos o comentarios.
class _OriginalProgressSheet extends StatelessWidget {
  const _OriginalProgressSheet({required this.original});

  final DuplicateOriginal original;

  @override
  Widget build(BuildContext context) {
    final steps = buildTimeline(original.status, createdAt: original.createdAt);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
          const SizedBox(height: 16),
          Text('SOLICITUD ORIGINAL', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: Text('#${original.code}', style: _T.headlineMd())),
              TicketStatusChip(status: original.status, large: true),
            ],
          ),
          const SizedBox(height: 4),
          Text('Avance del caso al que se unió tu ticket.', style: _T.bodySm(_C.secondary)),
          const SizedBox(height: 20),
          for (var i = 0; i < steps.length; i++)
            _ProgressRow(step: steps[i], last: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.step, required this.last});

  final TimelineStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final done = step.state == PhaseState.done;
    final current = step.state == PhaseState.current;
    final color = current ? _C.primaryContainer : (done ? _C.onSurface : _C.containerHighest);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: done || current
                      ? Icon(current ? Symbols.radio_button_checked : Symbols.check, size: 13, color: _C.white)
                      : null,
                ),
                if (!last) Expanded(child: Container(width: 2, color: _C.containerHigh)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.status.label,
                    style: _T.labelLg(current ? _C.primaryContainer : (done ? _C.onSurface : _C.secondary)),
                  ),
                  const SizedBox(height: 2),
                  Text(step.description, style: _T.bodySm(_C.secondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Textos =====================

/// La categoría del formulario que corresponde al texto del servidor
/// ("Electricidad", "Eléctrica", "Baños"...), para su ícono y nombre largo.
FaultCategory? categoryFor(String text) {
  final t = text.toLowerCase();
  if (t.startsWith('el')) return FaultCategory.electrical;
  if (t.startsWith('ba')) return FaultCategory.bathrooms;
  if (t.startsWith('aire') || t.contains('clima')) return FaultCategory.airConditioning;
  if (t.startsWith('inm') || t.startsWith('mob')) return FaultCategory.furniture;
  return null;
}

/// "Estado operativo" en palabras simples, según el estado del original.
String operationalStatus(TicketStatus s) => switch (s) {
      TicketStatus.received => 'Esperando revisión de Servicios Generales',
      TicketStatus.inReview => 'Derivando a un Administrador',
      TicketStatus.approved => 'Reparación aprobada, por asignar técnico',
      TicketStatus.inProgress => 'Técnico trabajando en la reparación',
      TicketStatus.resolved => 'Reparación terminada',
      TicketStatus.closed => 'Caso cerrado',
      TicketStatus.rejected => 'La solicitud no procede',
      TicketStatus.cancelled => 'Solicitud cancelada',
    };

/// "hace 45 min" · "hace 3 h" · "hace 2 días".
String timeAgo(DateTime date, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(date);
  if (d.inMinutes < 1) return 'hace un momento';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return d.inDays == 1 ? 'hace 1 día' : 'hace ${d.inDays} días';
}
