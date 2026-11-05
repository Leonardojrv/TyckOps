import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Campo de texto con etiqueta arriba (como en los mockups) y, si es una
/// contraseña, con el ícono de "ojo" para mostrarla u ocultarla.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.trailingLabel,
    this.trailingLabelColor,
    this.helperText,
    this.isPassword = false,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.autofillHints,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final String? trailingLabel; // texto pequeño a la derecha ("Chile HQ", "Recomendado")
  final Color? trailingLabelColor;
  final String? helperText;
  final bool isPassword;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.isPassword;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (widget.trailingLabel != null)
              Text(
                widget.trailingLabel!,
                style: AppTypography.bodySmall.copyWith(
                  color: widget.trailingLabelColor ?? AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          validator: widget.validator,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          maxLines: isPassword ? 1 : widget.maxLines,
          style: AppTypography.bodyLarge,
          // Seguridad: las contraseñas no se muestran, no se autocorrigen
          // y el teclado no las aprende ni las sugiere.
          obscureText: isPassword && _obscured,
          enableSuggestions: !isPassword,
          autocorrect: !isPassword,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            helperMaxLines: 2,
            prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
            suffixIcon: isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    icon: Icon(_obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
