// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Detalle del ticket" (T7).
//
// ¿QUÉ HACE?
//   Muestra la ficha, la foto (se agranda al tocarla), el motivo si fue rechazado,
//   los comentarios del administrador y la línea de tiempo. Si el ticket sigue
//   Recibido, agrega el botón "Cancelar ticket" con su confirmación (T9).
//   T10: si el ticket es un duplicado, muestra el aviso de ticket agrupado; si
//   es de prioridad Baja, muestra la guía de solución IA con sus acciones.
//
// ¿CÓMO LO CAMBIO?
//   Las fases y sus textos están en ticket_logic.dart. El visor de la foto está en
//   core/widgets/photo_viewer.dart.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/ticket_time.dart';
import '../../../core/navigation/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/photo_viewer.dart';
import '../../../data/models/self_help.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/ticket_detail.dart';
import '../../../data/models/ticket_status.dart';
import '../../../data/repositories/ticket_repository.dart';
import '../worker_tokens.dart';
import 'assisted_guide_view.dart';
import 'cancel_ticket_sheet.dart';
import 'duplicate_ticket_view.dart';
import 'ticket_logic.dart';
import 'ticket_status_chip.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

/// T7 · Detalle de un ticket del colaborador.
///
/// Se arma según el estado (mockups colaborador/detalle_ticket_en_proceso y
/// detalle_ticket_rechazado):
/// - En curso o terminado: ficha, foto, comentarios y "Trazabilidad del Servicio".
/// - Rechazado: caja "Motivo del rechazo", comentarios e "Historial de resolución".
///
/// Los comentarios del administrador van siempre ANTES de la línea de tiempo,
/// son de solo lectura y el más reciente lleva la etiqueta "NUEVO".
/// Si tocas la foto, se abre en grande (visor compartido con el administrador).
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.repository,
    this.onCancel,
    this.onResolveGuide,
  });

  final String ticketId;
  final TicketRepository repository;

  /// T9 · Cancela el ticket (lo entrega MyTicketsStore para que la lista y el
  /// home se actualicen). Si es null, el botón "Cancelar ticket" no aparece.
  final Future<Ticket> Function(String id)? onCancel;

  /// T10 · Cierra o escala el ticket desde la guía (también lo entrega
  /// MyTicketsStore). Si es null, la guía no se muestra.
  final Future<Ticket> Function(String id, GuideAction action)? onResolveGuide;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late Future<TicketDetail> _detail = widget.repository.ticketDetail(widget.ticketId);

  // La foto se descarga una sola vez y se reutiliza en la miniatura y en el
  // visor. Vive solo mientras esta pantalla está abierta (no se guarda en disco).
  Future<Uint8List>? _photo;
  Future<Uint8List> _loadPhoto() => _photo ??= widget.repository.ticketPhoto(widget.ticketId);

  void _back() => context.go(Routes.workerTickets);

  Future<void> _reload() async {
    setState(() {
      _photo = null;
      _detail = widget.repository.ticketDetail(widget.ticketId);
    });
    await _detail.then((_) {}, onError: (_) {});
  }

  // T9 · Pide confirmar y, si la persona acepta, cancela en el servidor.
  // La hoja queda abierta (con el botón ocupado) hasta que el servidor responde.
  Future<void> _confirmCancel(Ticket ticket) async {
    final cancel = widget.onCancel;
    if (cancel == null) return;
    String? message;
    await showCancelTicketSheet(
      context,
      code: ticket.code,
      onConfirm: () async {
        try {
          await cancel(ticket.id);
          message = 'Cancelaste la solicitud #${ticket.code}.';
        } on ApiException catch (e) {
          // Por ejemplo: el administrador ya la pasó a revisión (409).
          message = e.message;
        } catch (_) {
          message = 'No pudimos cancelar la solicitud. Intenta nuevamente.';
        }
      },
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message!), behavior: SnackBarBehavior.floating));
    // Se vuelve a pedir el detalle: el botón desaparece y la línea de tiempo
    // muestra "Cancelado" (o el estado real, si no se pudo cancelar).
    await _reload();
  }

  // T10 · Después de cerrar o escalar desde la guía: aviso y detalle nuevo.
  Future<void> _afterGuide(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
    await _reload();
  }

  void _openPhoto(TicketDetail d) {
    showPhotoViewer(
      context,
      loadPhoto: () {
        // Si falló antes, el visor permite reintentar con una descarga nueva.
        final current = _loadPhoto();
        return current.catchError((Object e) {
          _photo = null;
          throw e;
        });
      },
      title: 'Evidencia · #${d.ticket.code}',
      heroTag: 'ticket-photo-${d.ticket.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: _DetailHeader(onBack: _back),
      body: FutureBuilder<TicketDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final e = snapshot.error;
            final notFound = e is ApiException && e.statusCode == 404;
            return _ErrorState(
              message: notFound
                  ? 'No encontramos esa solicitud. Puede que ya no exista o que no sea tuya.'
                  : e is ApiException
                      ? e.message
                      : 'No pudimos cargar el detalle. Intenta nuevamente.',
              onRetry: notFound ? null : _reload,
              onBack: _back,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.primaryContainer));
          }
          final d = snapshot.data!;

          // T10 · Ticket agrupado con otro: aviso del mockup en vez del detalle.
          if (d.duplicateOf != null) {
            return _SpecialView(
              onRefresh: _reload,
              child: DuplicateTicketView(
                ticket: d.ticket,
                original: d.duplicateOf!,
                onGoHome: () => context.go(Routes.workerHome),
              ),
            );
          }
          // T10 · Prioridad Baja y Recibido: guía de solución IA con sus acciones.
          final resolveGuide = widget.onResolveGuide;
          if (d.selfHelp && resolveGuide != null) {
            return _SpecialView(
              onRefresh: _reload,
              child: AssistedGuideView(
                key: ValueKey('guia-${d.ticket.id}'),
                ticket: d.ticket,
                loadGuide: () => widget.repository.selfHelpGuide(d.ticket.id),
                onResolve: (action) => resolveGuide(d.ticket.id, action),
                onDone: _afterGuide,
              ),
            );
          }

          final rejected = d.ticket.status == TicketStatus.rejected;
          final timeline = buildTimeline(
            d.ticket.status,
            createdAt: d.ticket.createdAt,
            closedAt: d.closedAt,
            closedBySelfHelp: d.closedBySelfHelp,
          );

          return RefreshIndicator(
            color: _C.primaryContainer,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _BackLink(onTap: _back),
                const SizedBox(height: 8),
                if (rejected) ...[
                  _RejectedHeaderCard(detail: d, onOpenPhoto: () => _openPhoto(d), loadPhoto: _loadPhoto),
                  const SizedBox(height: 24),
                  _RejectionReasonCard(reason: d.visibleRejectionReason, decidedAt: d.closedAt),
                ] else ...[
                  _HeaderCard(ticket: d.ticket),
                  const SizedBox(height: 16),
                  _IncidentCard(detail: d, onOpenPhoto: () => _openPhoto(d), loadPhoto: _loadPhoto),
                ],
                if (d.comments.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _CommentsCard(comments: d.comments),
                ],
                const SizedBox(height: 24),
                _TimelineCard(steps: timeline, rejected: rejected, detail: d),
                // T9 · RF-09: solo mientras está Recibido (el servidor lo vuelve a revisar).
                if (d.ticket.status.canBeCancelled && widget.onCancel != null) ...[
                  const SizedBox(height: 24),
                  CancelTicketSection(onPressed: () => _confirmCancel(d.ticket)),
                ],
                if (rejected) ...[
                  const SizedBox(height: 24),
                  const _HelpBanner(),
                  const SizedBox(height: 24),
                  _PrimaryButton(
                    icon: Symbols.add_circle,
                    label: 'Crear nueva solicitud',
                    onPressed: () => context.go(Routes.workerReport),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ===================== Encabezado =====================

/// T10 · Contenedor de las vistas especiales (guía y duplicado): mismo fondo,
/// márgenes y "deslizar para recargar" que el detalle normal.
class _SpecialView extends StatelessWidget {
  const _SpecialView({required this.child, required this.onRefresh});

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _C.primaryContainer,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [child],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget implements PreferredSizeWidget {
  const _DetailHeader({required this.onBack});

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
                // Flecha para volver, como en los mockups de la T10.
                IconButton(
                  tooltip: 'Regresar',
                  onPressed: onBack,
                  icon: const Icon(Symbols.arrow_back, size: 24, color: _C.onSurface),
                ),
                const SizedBox(width: 4),
                Expanded(child: Text('Detalle del Ticket', style: _T.headlineSm(), overflow: TextOverflow.ellipsis)),
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

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.arrow_back, size: 18, color: _C.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('Volver a mis solicitudes', style: _T.labelMd(_C.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Ticket en curso =====================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return _Card(
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
                    Text('INCIDENCIA TÉCNICA', style: _T.caption(_C.secondary).copyWith(letterSpacing: 0.5)),
                    Text(
                      'Ticket #${ticket.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _T.headlineLg().copyWith(letterSpacing: -0.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DetailChip(status: ticket.status),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Symbols.tune, size: 16, color: _C.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Reparación / ${ticket.category}', style: _T.bodySm(_C.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip del encabezado del detalle: en curso lleva el punto rojo que late.
class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.isActiveStatus) return TicketStatusChip(status: status, large: true);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PulsingDot(color: _C.primaryContainer, size: 8),
          const SizedBox(width: 6),
          Text(status.label, style: _T.labelSm()),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.detail, required this.onOpenPhoto, required this.loadPhoto});

  final TicketDetail detail;
  final VoidCallback onOpenPhoto;
  final Future<Uint8List> Function() loadPhoto;

  @override
  Widget build(BuildContext context) {
    final t = detail.ticket;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('FICHA DE INCIDENCIA', style: _T.labelLg().copyWith(letterSpacing: 0.4))),
              Text(_priorityLabel(t.priority), style: _T.caption(_C.secondary)),
            ],
          ),
          const SizedBox(height: 16),
          _InfoBlock(
            label: 'DIAGNÓSTICO REPORTADO',
            child: Text(detail.description, style: _T.bodyMd().copyWith(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          _IconInfoBlock(icon: Symbols.location_on, label: 'Ubicación física', value: t.location),
          const SizedBox(height: 16),
          _Evidence(detail: detail, onOpen: onOpenPhoto, loadPhoto: loadPhoto),
        ],
      ),
    );
  }
}

// ===================== Ticket rechazado =====================

class _RejectedHeaderCard extends StatelessWidget {
  const _RejectedHeaderCard({required this.detail, required this.onOpenPhoto, required this.loadPhoto});

  final TicketDetail detail;
  final VoidCallback onOpenPhoto;
  final Future<Uint8List> Function() loadPhoto;

  @override
  Widget build(BuildContext context) {
    final t = detail.ticket;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('TICKET #${t.code}', style: _T.labelMd(_C.secondary).copyWith(letterSpacing: 0.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _C.errorContainer, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.cancel, size: 14, color: _C.onErrorContainer),
                    const SizedBox(width: 6),
                    Text('Rechazado', style: _T.labelSm(_C.onErrorContainer).copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(detail.description, style: _T.headlineMd()),
          const SizedBox(height: 2),
          Text(t.location, style: _T.bodySm(_C.secondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Symbols.build, size: 20, color: _C.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Reparación · ${t.category}', style: _T.labelMd())),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(4)),
                  child: Text(_priorityLabel(t.priority), style: _T.labelSm(_C.secondary)),
                ),
              ],
            ),
          ),
          if (detail.hasPhoto) ...[
            const SizedBox(height: 16),
            _Evidence(detail: detail, onOpen: onOpenPhoto, loadPhoto: loadPhoto),
          ],
        ],
      ),
    );
  }
}

/// Caja "Motivo del rechazo" (RF-07). Solo existe en tickets rechazados.
class _RejectionReasonCard extends StatelessWidget {
  const _RejectionReasonCard({required this.reason, required this.decidedAt});

  final String? reason;
  final DateTime? decidedAt;

  @override
  Widget build(BuildContext context) {
    final when = decidedAt == null ? null : formatTicketTime(decidedAt!);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: _C.primaryContainer), // franja roja del mockup
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(color: _C.errorContainer, shape: BoxShape.circle),
                      child: const Icon(Symbols.error, size: 20, color: _C.primaryContainer),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Motivo del rechazo', style: _T.headlineSm()),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              reason == null ? 'Servicios Generales no dejó un motivo escrito.' : '"$reason"',
                              style: _T.bodyMd().copyWith(fontStyle: FontStyle.italic, height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Symbols.verified_user, size: 16, color: _C.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  when == null ? 'Servicios Generales' : 'Servicios Generales · $when',
                                  style: _T.labelSm(_C.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Foto (evidencia) =====================

class _Evidence extends StatelessWidget {
  const _Evidence({required this.detail, required this.onOpen, required this.loadPhoto});

  final TicketDetail detail;
  final VoidCallback onOpen;
  final Future<Uint8List> Function() loadPhoto;

  @override
  Widget build(BuildContext context) {
    final has = detail.hasPhoto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVIDENCIA ADJUNTA (${has ? 1 : 0} ${has ? 'REGISTRO' : 'REGISTROS'})',
          style: _T.caption(_C.secondary).copyWith(letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        if (!has)
          Text('No adjuntaste fotografía en este reporte.', style: _T.bodySm(_C.secondary))
        else
          Row(
            children: [
              _PhotoThumb(heroTag: 'ticket-photo-${detail.ticket.id}', loadPhoto: loadPhoto, onTap: onOpen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fotografía del reporte', style: _T.labelMd(), overflow: TextOverflow.ellipsis),
                    Text(
                      'Subida ${_lower(formatTicketTime(detail.ticket.createdAt))}',
                      style: _T.caption(_C.secondary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Symbols.verified, size: 12, color: _C.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Toca la foto para verla en grande',
                            style: _T.caption(_C.primary).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Miniatura de 80×80. La foto se descarga al aparecer y se reutiliza en el visor.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.heroTag, required this.loadPhoto, required this.onTap});

  final String heroTag;
  final Future<Uint8List> Function() loadPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver fotografía en grande',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 80,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(8), boxShadow: workerShadowSm),
          child: FutureBuilder<Uint8List>(
            future: loadPhoto(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Icon(Symbols.broken_image, size: 24, color: _C.secondary);
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _C.secondary)),
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: heroTag,
                    // La miniatura se carga en tamaño pequeño para no gastar memoria del teléfono.
                    child: Image.memory(snapshot.data!, fit: BoxFit.cover, cacheWidth: 240, gaplessPlayback: true),
                  ),
                  Container(
                    color: _C.inverseSurface.withValues(alpha: 0.2),
                    child: const Icon(Symbols.zoom_in, size: 20, color: _C.white),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ===================== Comentarios del administrador =====================

/// Tarjeta de solo lectura con los comentarios del administrador de ESTE
/// ticket. El más reciente lleva "NUEVO". No hay respuestas ni chat.
class _CommentsCard extends StatelessWidget {
  const _CommentsCard({required this.comments});

  final List<TicketComment> comments; // del más antiguo al más nuevo

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Symbols.verified_user, size: 18, color: _C.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  comments.length == 1 ? 'COMENTARIO DEL ADMINISTRADOR' : 'COMENTARIOS DEL ADMINISTRADOR',
                  style: _T.labelLg().copyWith(letterSpacing: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < comments.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: _C.container)),
            _CommentItem(comment: comments[i], isNewest: i == comments.length - 1),
          ],
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({required this.comment, required this.isNewest});

  final TicketComment comment;
  final bool isNewest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Nombre + etiqueta a la izquierda; la hora siempre pegada a la derecha.
            Expanded(
              child: Row(
                children: [
                  Flexible(child: Text(comment.author, style: _T.labelMd(), overflow: TextOverflow.ellipsis)),
                  if (isNewest) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(4)),
                      child: Text('NUEVO', style: _T.caption(_C.white).copyWith(fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(formatTicketTime(comment.createdAt), style: _T.caption(_C.secondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(comment.text, style: _T.bodySm(_C.onSurfaceVariant).copyWith(height: 1.6)),
      ],
    );
  }
}

// ===================== Línea de tiempo =====================

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.steps, required this.rejected, required this.detail});

  final List<TimelineStep> steps;
  final bool rejected;
  final TicketDetail detail;

  @override
  Widget build(BuildContext context) {
    final currentIndex = steps.indexWhere((s) => s.state == PhaseState.current);
    final elapsed = detail.closedAt?.difference(detail.ticket.createdAt);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: rejected
                    ? Text('HISTORIAL DE RESOLUCIÓN', style: _T.labelLg().copyWith(letterSpacing: 0.6))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trazabilidad del Servicio', style: _T.labelLg()),
                          Text('Flujo oficial de tu solicitud', style: _T.caption(_C.secondary)),
                        ],
                      ),
              ),
              if (rejected && elapsed != null)
                Text('Tiempo transcurrido: ${_duration(elapsed)}', style: _T.caption(_C.secondary))
              else if (!rejected && currentIndex >= 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _C.containerHigh, borderRadius: BorderRadius.circular(999)),
                  child: Text('Fase ${currentIndex + 1} de ${steps.length}', style: _T.labelSm(_C.onSurfaceVariant)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              step: steps[i],
              number: rejected ? null : i + 1,
              rejectedFlow: rejected,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.number, required this.rejectedFlow, required this.isLast});

  final TimelineStep step;
  final int? number; // "1. Recibido" en el flujo normal; sin número en el rechazado
  final bool rejectedFlow;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final current = step.state == PhaseState.current;
    final pending = step.state == PhaseState.pending;
    final endsBad = step.status == TicketStatus.rejected || step.status == TicketStatus.cancelled;
    final title = number == null ? step.status.label : '$number. ${step.status.label}';

    // Columna izquierda: el círculo de la fase y la línea que une con la siguiente.
    final marker = SizedBox(
      width: 24,
      child: Column(
        children: [
          const SizedBox(height: 2),
          _Marker(state: step.state, rejectedFlow: rejectedFlow, endsBad: endsBad),
          if (!isLast) Expanded(child: Container(width: 2, color: _C.containerHigh)),
        ],
      ),
    );

    final titleColor = pending
        ? _C.secondary.withValues(alpha: 0.6)
        : current
            ? (endsBad ? _C.primaryContainer : _C.primary)
            : _C.onSurface;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Título (+ "ACTIVO") a la izquierda; la fecha siempre pegada a la derecha.
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: _T.labelMd(titleColor).copyWith(fontWeight: current && !endsBad ? FontWeight.w700 : FontWeight.w600),
                    ),
                  ),
                  if (current && !endsBad) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(4)),
                      child: Text('ACTIVO', style: _T.caption(_C.white).copyWith(fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              pending ? 'Pendiente' : (step.date == null ? '' : formatTicketTime(step.date!)),
              style: _T.caption(pending ? _C.secondary.withValues(alpha: 0.6) : (current ? titleColor : _C.secondary))
                  .copyWith(fontWeight: current ? FontWeight.w600 : FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          step.description,
          style: _T.bodySm(pending ? _C.secondary.withValues(alpha: 0.6) : (current ? _C.onSurface : _C.onSurfaceVariant)),
        ),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          marker,
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              // La fase actual del flujo normal va resaltada en un recuadro gris.
              child: current && !endsBad
                  ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
                      child: content,
                    )
                  : content,
            ),
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.state, required this.rejectedFlow, required this.endsBad});

  final PhaseState state;
  final bool rejectedFlow;
  final bool endsBad;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case PhaseState.done:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: rejectedFlow ? _C.containerHighest : _C.inverseSurface,
            shape: BoxShape.circle,
            border: Border.all(color: _C.white, width: 2),
          ),
          child: Icon(Symbols.check, size: 14, color: rejectedFlow ? _C.onSurface : _C.white),
        );
      case PhaseState.current:
        if (endsBad) {
          return Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle),
            child: const Icon(Symbols.close, size: 14, color: _C.white),
          );
        }
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _C.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: _C.primaryFixed, width: 3),
          ),
          child: const Center(child: PulsingDot(color: _C.white, size: 7)),
        );
      case PhaseState.pending:
        return SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: _C.containerHigh, shape: BoxShape.circle, border: Border.all(color: _C.white, width: 2)),
            ),
          ),
        );
    }
  }
}

// ===================== Piezas comunes =====================

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: child,
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _T.caption(_C.secondary).copyWith(letterSpacing: 0.4)),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

class _IconInfoBlock extends StatelessWidget {
  const _IconInfoBlock({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: _C.containerHigh, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: _C.onSurface),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _T.caption(_C.secondary)),
                Text(value, style: _T.labelMd(), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpBanner extends StatelessWidget {
  const _HelpBanner();

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
            child: const Icon(Symbols.lightbulb, size: 20, color: _C.secondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Necesitas asistencia técnica urgente?', style: _T.labelMd()),
                Text(
                  'Puedes escalar el ticket al supervisor de turno directamente por la mesa de ayuda.',
                  style: _T.bodySm(_C.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
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
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: _T.labelLg(_C.white)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack, this.onRetry});

  final String message;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.find_in_page, size: 40, color: _C.secondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: _T.bodyMd(_C.secondary)),
            const SizedBox(height: 16),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text('Reintentar', style: _T.labelLg(_C.primaryContainer))),
            TextButton(onPressed: onBack, child: Text('Volver a mis solicitudes', style: _T.labelLg(_C.secondary))),
          ],
        ),
      ),
    );
  }
}

// ===================== Textos =====================

String _priorityLabel(TicketPriority? p) => switch (p) {
      TicketPriority.high => 'Prioridad Alta',
      TicketPriority.medium => 'Prioridad Media',
      TicketPriority.low => 'Prioridad Baja',
      null => 'Prioridad por asignar',
    };

String _lower(String s) => s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';

/// 18h 20m · 3d 4h · 25m
String _duration(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}
