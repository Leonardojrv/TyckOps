// ¿PARA QUÉ SIRVE?
//   Son las 6 casillas donde se escribe el código de verificación. Es un
//   componente GENÉRICO: lo usa el colaborador (T8) y lo usará el administrador
//   (T12) con sus propios colores.
//
// ¿QUÉ HACE?
//   Muestra una casilla por dígito, abre el teclado numérico al tocarlas, marca
//   la casilla actual con un cursor y permite pegar el código copiado (mantener
//   presionado). Si el código queda completo, avisa con onCompleted.
//
// ¿CÓMO LO CAMBIO?
//   Los colores y tamaños vienen en OtpFieldStyle: para el administrador basta
//   pasarle otro estilo. El largo del código está en mfa_logic.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mfa_logic.dart';

/// Colores y medidas de las casillas (los valores por defecto copian el
/// mockup del colaborador).
class OtpFieldStyle {
  const OtpFieldStyle({
    this.filledColor = const Color(0xFFEEEEEE), // casilla con número
    this.activeColor = const Color(0x66FFDAD6), // casilla donde va el cursor
    this.activeBorder = const Color(0xFFD7282F),
    this.emptyColor = const Color(0xFFFFFFFF),
    this.emptyBorder = const Color(0xFFE2E2E2),
    this.errorBorder = const Color(0xFFBA1A1A),
    this.digitStyle = const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1C)),
    this.placeholderColor = const Color(0xFFC6C6C6),
    this.height = 56,
    this.radius = 12,
    this.gap = 8,
  });

  final Color filledColor;
  final Color activeColor;
  final Color activeBorder;
  final Color emptyColor;
  final Color emptyBorder;
  final Color errorBorder;
  final TextStyle digitStyle;
  final Color placeholderColor;
  final double height;
  final double radius;
  final double gap;
}

class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.focusNode,
    this.length = mfaCodeLength,
    this.hasError = false,
    this.enabled = true,
    this.onCompleted,
    this.onPasted,
    this.style = const OtpFieldStyle(),
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int length;
  final bool hasError; // borde rojo cuando el código fue rechazado
  final bool enabled;
  final ValueChanged<String>? onCompleted;
  final VoidCallback? onPasted; // para avisar "Código pegado"
  final OtpFieldStyle style;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> with SingleTickerProviderStateMixin {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  // El cursor parpadea como en el mockup (animate-pulse).
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.removeListener(_changed);
    if (widget.focusNode == null) _focus.dispose();
    _blink.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final code = widget.controller.text;
    if (code.length == widget.length) widget.onCompleted?.call(code);
  }

  // Mantener presionado: pega el código desde el portapapeles (solo los números).
  Future<void> _paste() async {
    if (!widget.enabled) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final code = sanitizeCode(data?.text ?? '', length: widget.length);
    if (code.isEmpty) return;
    widget.controller.value = TextEditingValue(text: code, selection: TextSelection.collapsed(offset: code.length));
    widget.onPasted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final code = widget.controller.text;
    final focused = _focus.hasFocus;

    return Semantics(
      label: 'Código de verificación de ${widget.length} dígitos. ${code.length} escritos.',
      textField: true,
      child: GestureDetector(
        onTap: widget.enabled ? () => _focus.requestFocus() : null,
        onLongPress: _paste,
        child: Stack(
          children: [
            // Campo invisible que recibe el teclado (y el autocompletado de códigos).
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableSuggestions: false,
                  autocorrect: false,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                ),
              ),
            ),
            // Las casillas que se ven.
            IgnorePointer(
              child: Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) SizedBox(width: s.gap),
                    Expanded(child: _box(i, code, focused)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(int i, String code, bool focused) {
    final s = widget.style;
    final filled = i < code.length;
    final active = focused && widget.enabled && i == code.length.clamp(0, widget.length - 1) && code.length < widget.length;
    final Color bg = filled ? s.filledColor : (active ? s.activeColor : s.emptyColor);
    final Border? border = widget.hasError
        ? Border.all(color: s.errorBorder, width: 2)
        : active
            ? Border.all(color: s.activeBorder, width: 2)
            : filled
                ? null
                : Border.all(color: s.emptyBorder);

    final Widget content = filled
        ? Text(code[i], style: s.digitStyle)
        : active
            ? FadeTransition(
                opacity: _blink,
                child: Text('|', style: s.digitStyle.copyWith(color: s.activeBorder)),
              )
            : Text('•', style: s.digitStyle.copyWith(color: s.placeholderColor, fontSize: s.digitStyle.fontSize)) ;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: s.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(s.radius),
        border: border,
        boxShadow: active ? const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))] : null,
      ),
      child: content,
    );
  }
}
