// ¿PARA QUÉ SIRVE?
//   Es el botón "Cancelar ticket" del detalle y la hoja que pide confirmar
//   antes de cancelar (T9 · mockup colaborador/cancelaci_n_de_ticket_y_modal).
//
// ¿QUÉ HACE?
//   CancelTicketSection muestra el aviso, el botón y la nota de abajo.
//   showCancelTicketSheet abre la hoja "¿Deseas cancelar este ticket?" con
//   "Sí, cancelar ticket" y "Volver". Mientras se cancela, la hoja no se puede
//   cerrar y el botón muestra que está trabajando.
//
// ¿CÓMO LO CAMBIO?
//   Los textos están aquí mismo. La regla de cuándo se puede cancelar está en
//   TicketStatus.canBeCancelled (y el servidor la vuelve a revisar siempre).

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

/// Aviso + botón "Cancelar ticket" + nota. Solo se muestra en tickets Recibidos.
class CancelTicketSection extends StatelessWidget {
  const CancelTicketSection({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Aviso del mockup: explica por qué todavía se puede cancelar.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Symbols.info, size: 18, color: _C.secondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este ticket está en espera de revisión por Servicios Generales. '
                  'Puedes cancelarlo directamente antes de que comience la atención.',
                  style: _T.bodySm(_C.secondary).copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _C.white,
              foregroundColor: _C.primary,
              overlayColor: _C.errorContainer,
              elevation: 1,
              shadowColor: const Color(0x14000000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.delete, size: 20, color: _C.primary),
                const SizedBox(width: 8),
                Text('Cancelar ticket', style: _T.labelLg(_C.primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Esta opción se deshabilitará automáticamente cuando Servicios Generales comience a revisar tu solicitud.',
          textAlign: TextAlign.center,
          style: _T.caption(_C.secondary).copyWith(fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}

/// Abre la hoja de confirmación. [onConfirm] hace la cancelación de verdad;
/// la hoja espera a que termine (con el botón ocupado) y luego se cierra.
///
/// Devuelve true si la persona confirmó, o null si eligió "Volver" o cerró la hoja.
Future<bool?> showCancelTicketSheet(
  BuildContext context, {
  required String code,
  required Future<void> Function() onConfirm,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    // Sobre toda la app (también sobre la barra inferior), como en el mockup.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: _C.inverseSurface.withValues(alpha: 0.4),
    builder: (_) => _CancelSheet(code: code, onConfirm: onConfirm),
  );
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({required this.code, required this.onConfirm});

  final String code;
  final Future<void> Function() onConfirm;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras cancela, ni el botón "atrás" ni tocar afuera cierran la hoja:
    // así nadie queda sin saber si se canceló o no.
    return PopScope(
      canPop: !_busy,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, -4))],
        ),
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
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: _C.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Symbols.warning, size: 26, color: _C.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('¿Deseas cancelar este ticket?', style: _T.headlineMd().copyWith(height: 1.2)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TICKET #${widget.code}',
                        style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
              child: Text.rich(
                TextSpan(
                  style: _T.bodyMd().copyWith(height: 1.6),
                  children: [
                    const TextSpan(text: 'Esta acción no se puede deshacer. El requerimiento será marcado como '),
                    TextSpan(text: 'Cancelado', style: _T.bodyMd(_C.primary).copyWith(fontWeight: FontWeight.w600)),
                    const TextSpan(text: ' y saldrá de la cola de atención de Servicios Generales.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: _C.primary,
                  disabledBackgroundColor: _C.primary.withValues(alpha: 0.7),
                  foregroundColor: _C.white,
                  overlayColor: _C.onPrimaryFixed,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _C.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Bote de basura, como en el mockup.
                          const Icon(Symbols.delete, size: 20, color: _C.white),
                          const SizedBox(width: 8),
                          Text('Sí, cancelar ticket', style: _T.labelLg(_C.white)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.containerHigh,
                  disabledBackgroundColor: _C.containerHigh,
                  foregroundColor: _C.onSurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Volver', style: _T.labelLg(_busy ? _C.secondary : _C.onSurface)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
