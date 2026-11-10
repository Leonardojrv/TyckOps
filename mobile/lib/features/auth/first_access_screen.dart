import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/network/api_exception.dart';
import '../../core/validators.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_session.dart';
import 'terms_content.dart';

/// Primer acceso (RF-02 y RF-03): cambiar la contraseña temporal o mantenerla,
/// y aceptar los Términos y Condiciones (sin aceptarlos no se puede continuar).
/// Mockup: docs/mockups/login/primer_acceso_y_seguridad_del_colaborador
///
/// Pendiente en la T4: botón "Rechazar términos" y registro en el servidor.
class FirstAccessScreen extends StatefulWidget {
  const FirstAccessScreen({super.key, required this.session, required this.authRepository});

  final AuthSession session;
  final AuthRepository authRepository;

  @override
  State<FirstAccessScreen> createState() => _FirstAccessScreenState();
}

class _FirstAccessScreenState extends State<FirstAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _termsChecked = false; // RF-03: obligatoria para continuar
  bool _loading = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  /// "Guardar preferencias y continuar": si se escribió una contraseña nueva
  /// la cambia; si el campo quedó vacío, mantiene la actual.
  Future<void> _save() => _complete(changePassword: _newPassword.text.isNotEmpty);

  /// "Omitir por ahora": mantiene la contraseña actual.
  Future<void> _skip() => _complete(changePassword: false);

  Future<void> _complete({required bool changePassword}) async {
    if (!_termsChecked) return; // segunda barrera, por si el botón fallara
    FocusScope.of(context).unfocus();
    if (changePassword && !_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = await widget.authRepository.completeFirstAccess(
        currentPassword: changePassword ? _currentPassword.text : null,
        newPassword: changePassword ? _newPassword.text : null,
      );
      // Seguridad: las claves no se quedan escritas en memoria.
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      // Con isFirstLogin = false, el router lleva solo al home del rol.
      widget.session.updateUser(user);
    } on ApiException catch (e) {
      _currentPassword.clear();
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.session.user?.role.label ?? 'Colaborador';
    return Scaffold(
      backgroundColor: _C.surface,
      // La flecha "volver" cierra la sesión y regresa al login.
      appBar: _Header(onBack: _loading ? null : widget.session.signOut),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HeroBanner(),
                const SizedBox(height: 16),
                _IdentityCard(title: '$roleLabel GA.MA Chile'),
                const SizedBox(height: 16),
                _CredentialsCard(
                  current: _currentPassword,
                  newPassword: _newPassword,
                  confirm: _confirmPassword,
                  enabled: !_loading,
                  onNewPasswordChanged: () => setState(() {}), // actualiza el medidor
                ),
                const SizedBox(height: 16),
                _TermsCard(
                  checked: _termsChecked,
                  onChanged: _loading ? null : (value) => setState(() => _termsChecked = value),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(
                      child: _InfoTile(icon: Symbols.lock_clock, title: 'SESIÓN ACTIVA', value: '90 días continuos'),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _InfoTile(icon: Symbols.encrypted, title: 'CIFRADO', value: 'AES-256 Corporativo'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // RF-03: sin marcar la casilla de términos no se puede continuar.
                _PrimaryButton(loading: _loading, enabled: _termsChecked, onPressed: _save),
                const SizedBox(height: 8),
                TextButton(
                  // "Omitir" solo salta el cambio de contraseña, no los términos
                  // (decisión del equipo, docs/mockups/README.md).
                  onPressed: _loading || !_termsChecked ? null : _skip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    overlayColor: Colors.transparent,
                  ),
                  child: Text(
                    'Omitir por ahora y usar configuración predeterminada',
                    textAlign: TextAlign.center,
                    style: _T
                        .bodySm(_termsChecked ? _C.secondary : _C.disabledText)
                        .copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: _termsChecked ? _C.secondary : _C.disabledText,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== Encabezado =====================

class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({required this.onBack});

  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _C.surface,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                onPressed: onBack,
                tooltip: 'Volver al inicio de sesión',
                constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                icon: const Icon(Symbols.arrow_back, size: 24, color: _C.onSurface),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Configuración De Cuenta', style: _T.headlineSm(), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Banner oscuro =====================

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.inverseSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _shadowSm,
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _BrandChip(),
                    const Spacer(),
                    Text('TYCKOPS V2.4', style: _T.caption(_C.surfaceDim).copyWith(letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Configuración de Cuenta',
                  style: _T.headlineLg(_C.inverseOnSurface).copyWith(letterSpacing: -0.6),
                ),
                const SizedBox(height: 2),
                Text('Seguridad y Políticas de Acceso GA.MA Chile', style: _T.bodySm(_C.surfaceDim)),
                const SizedBox(height: 12),
                const _StepBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Patrón de puntos blancos al 10 % (cada 16 px), como en el mockup.
class _DotPatternPainter extends CustomPainter {
  const _DotPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1AFFFFFF);
    for (double y = 2; y < size.height; y += 16) {
      for (double x = 2; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) => false;
}

class _BrandChip extends StatelessWidget {
  const _BrandChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: _C.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDot(),
          const SizedBox(width: 4),
          Text('GA.MA ITALY PROFESSIONAL', style: _T.labelSm(_C.primaryFixedDim).copyWith(letterSpacing: 0.55)),
        ],
      ),
    );
  }
}

/// Punto rojo que "late" (animate-pulse del mockup).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(begin: 1, end: 0.5).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: _C.inverseSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: _C.primary, shape: BoxShape.circle),
            child: const Icon(Symbols.shield_person, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('Paso 1 de 1 · Activación inicial', style: _T.labelMd(_C.surfaceBright))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _C.containerHigh.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Obligatorio', style: _T.caption(_C.surfaceDim)),
          ),
        ],
      ),
    );
  }
}

// ===================== Tarjetas =====================

/// Tarjeta blanca (radio 12, sombra suave). [accent] agrega la franja roja.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.accent = false});

  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(12), boxShadow: _shadowSm),
      child: Stack(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: child),
          if (accent)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(height: 4, child: ColoredBox(color: _C.primaryContainer)),
            ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Symbols.badge, size: 22, color: _C.primaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title, style: _T.labelLg(), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Symbols.check_circle, size: 15, color: _C.primary, fill: 1),
                  ],
                ),
                Text(
                  'Casa Matriz · Red de Infraestructura & Mantenimiento',
                  style: _T.caption(_C.secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de sección: ícono en cuadro de 32 px + título + texto a la derecha.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: _T.headlineSm())),
        trailing,
      ],
    );
  }
}

class _CredentialsCard extends StatelessWidget {
  const _CredentialsCard({
    required this.current,
    required this.newPassword,
    required this.confirm,
    required this.enabled,
    required this.onNewPasswordChanged,
  });

  final TextEditingController current;
  final TextEditingController newPassword;
  final TextEditingController confirm;
  final bool enabled;
  final VoidCallback onNewPasswordChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SectionHeader(
              icon: Symbols.key,
              iconBackground: _C.primaryFixed,
              iconColor: _C.onPrimaryFixedVariant,
              title: 'Credenciales de Acceso',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(999)),
                child: Text('Seguridad', style: _T.labelSm(_C.secondary)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Symbols.info, size: 18, color: _C.primaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Puedes mantener tu contraseña temporal asignada por el sistema o '
                    'personalizar una nueva contraseña de manera opcional.',
                    style: _T.bodySm(_C.secondary).copyWith(height: 1.375),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PasswordField(
            label: 'Contraseña temporal actual',
            trailing: 'Asignada vía IT',
            hint: '••••••••••••',
            icon: Symbols.lock,
            controller: current,
            enabled: enabled,
            autofillHints: const [AutofillHints.password],
            // Solo se exige si el usuario quiere cambiar su contraseña.
            validator: (value) => newPassword.text.isNotEmpty && (value == null || value.isEmpty)
                ? 'Ingresa tu contraseña temporal para cambiarla'
                : null,
          ),
          const SizedBox(height: 16),
          _PasswordField(
            label: 'Nueva contraseña (Opcional)',
            trailing: 'Recomendado',
            trailingColor: _C.primaryContainer,
            hint: 'Dejar en blanco para mantener actual',
            icon: Symbols.lock_reset,
            controller: newPassword,
            enabled: enabled,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.optionalNewPassword,
            onChanged: (_) => onNewPasswordChanged(),
          ),
          const SizedBox(height: 4),
          _StrengthMeter(strength: Validators.passwordStrength(newPassword.text)),
          const SizedBox(height: 16),
          _PasswordField(
            label: 'Confirmar nueva contraseña',
            hint: 'Repite tu nueva contraseña',
            icon: Symbols.verified,
            controller: confirm,
            enabled: enabled,
            autofillHints: const [AutofillHints.newPassword],
            validator: (value) => Validators.confirmPassword(value, newPassword.text),
          ),
        ],
      ),
    );
  }
}

/// Campo de contraseña del mockup: fondo gris sin borde, blanco al enfocar,
/// ícono a la izquierda y "ojo" para mostrar u ocultar.
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.enabled,
    this.trailing,
    this.trailingColor = _C.secondary,
    this.validator,
    this.onChanged,
    this.autofillHints,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool enabled;
  final String? trailing;
  final Color trailingColor;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscured = true;

  OutlineInputBorder _border([Color? color]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label, style: _T.labelMd())),
            if (widget.trailing != null) Text(widget.trailing!, style: _T.caption(widget.trailingColor)),
          ],
        ),
        const SizedBox(height: 6),
        // Como en el mockup, el "ojo" flota sobre el campo (absolute right-2)
        // y el texto deja 40 px libres a la derecha (pr-10).
        Stack(
          children: [
            _field(),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => _obscured = !_obscured),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                // Mantiene los 32 px del mockup (Material 3 lo agrandaría a 48).
                style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                icon: Icon(_obscured ? Symbols.visibility : Symbols.visibility_off, size: 20, color: _C.secondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field() {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      validator: widget.validator,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      // Seguridad: la clave no se muestra, no se autocorrige y el teclado
      // no la aprende ni la sugiere.
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      style: _T.bodyMd(),
      decoration: InputDecoration(
        // "hint" como widget para que se dibuje completo, sin "…" (igual al mockup).
        hint: Text(
          widget.hint,
          style: _T.bodyMd(_C.secondary),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
        ),
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? _C.white : _C.containerLow,
        ),
        isDense: true,
        // 36 px a la derecha: el dibujo del "ojo" empieza a 34 px del borde.
        contentPadding: const EdgeInsets.fromLTRB(0, 14, 36, 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(widget.icon, size: 20, color: _C.secondary),
        ),
        prefixIconConstraints: const BoxConstraints(minHeight: 48),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(),
        disabledBorder: _border(),
        errorBorder: _border(_C.error),
        focusedErrorBorder: _border(_C.error),
        errorStyle: _T.caption(_C.error),
      ),
    );
  }
}

/// Barra de seguridad de la nueva contraseña (mismos niveles del mockup).
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final (factor, barColor, label, labelColor, weight) = switch (strength) {
      PasswordStrength.none => (0.0, _C.primaryContainer, 'Opcional', _C.secondary, FontWeight.w500),
      PasswordStrength.low => (0.3, _C.error, 'Baja', _C.error, FontWeight.w500),
      PasswordStrength.medium => (0.65, _C.primary, 'Media', _C.primary, FontWeight.w500),
      PasswordStrength.strong => (1.0, _C.inverseSurface, 'Robusta (Óptima)', _C.onSurface, FontWeight.w600),
    };
    return Semantics(
      label: 'Seguridad de la nueva contraseña: $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Criterio: mínimo 8 caracteres con letras y números', style: _T.caption(_C.secondary)),
              ),
              const SizedBox(width: 8),
              Text(label, style: _T.caption(labelColor).copyWith(fontWeight: weight)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: _C.containerHigh,
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                widthFactor: factor,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            icon: Symbols.gavel,
            iconBackground: _C.container,
            iconColor: _C.onSurface,
            title: 'Términos y Condiciones',
            trailing: Text('Doc. $termsDocCode', style: _T.labelSm(_C.secondary)),
          ),
          const SizedBox(height: 8),
          // Caja con scroll (144 px de alto, como el mockup) con el texto de
          // lib/features/auth/terms_content.dart.
          Container(
            constraints: const BoxConstraints(maxHeight: 144),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(termsTitle, style: _T.labelMd()),
                  const SizedBox(height: 2),
                  Text(termsSubtitle, style: _T.bodySm(_C.secondary)),
                  const SizedBox(height: 2),
                  Text(termsUpdatedAt, style: _T.caption(_C.secondary)),
                  for (final section in termsSections) ...[
                    const SizedBox(height: 12),
                    Text(section.title, style: _T.labelMd()),
                    for (final block in section.blocks) ...[const SizedBox(height: 4), _TermsBlockView(block)],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          MergeSemantics(
            child: Semantics(
              checked: checked,
              enabled: onChanged != null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChanged == null ? null : () => onChanged!(!checked),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: checked ? _C.primaryFixed.withValues(alpha: 0.2) : _C.containerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: checked ? _C.primaryContainer : _C.containerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: checked ? const Icon(Symbols.check, size: 18, color: Colors.white) : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'He leído y acepto los términos y condiciones de uso de la plataforma interna.',
                              style: _T.labelMd().copyWith(height: 1.25),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Requerido para activar privilegios de reporte técnico.',
                              style: _T.caption(_C.secondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja un bloque de los términos: párrafo, subtítulo o viñeta/numeración.
class _TermsBlockView extends StatelessWidget {
  const _TermsBlockView(this.block);

  final TermsBlock block;

  @override
  Widget build(BuildContext context) {
    final body = _T.bodySm(_C.secondary).copyWith(height: 1.625);
    final strong = _T.labelMd().copyWith(height: 21 / 12);
    return switch (block) {
      TermsParagraph(:final text) => Text(text, style: body),
      TermsSubheading(:final text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: strong),
      ),
      TermsItem(:final marker, :final label, :final text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 18, child: Text(marker, style: body)),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (label != null) TextSpan(text: '$label ', style: strong),
                    TextSpan(text: text, style: body),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    };
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(color: _C.secondaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: _C.primaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _T.caption(_C.secondary).copyWith(fontWeight: FontWeight.w600)),
                Text(value, style: _T.labelMd(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.loading, required this.enabled, required this.onPressed});

  final bool loading;
  final bool enabled; // false = gris y no responde (términos sin aceptar)
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final contentColor = enabled ? Colors.white : _C.disabledText;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: enabled ? _shadowSm : const []),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: loading || !enabled
              ? null
              : () {
                  HapticFeedback.lightImpact(); // pequeña vibración al tocar
                  onPressed();
                },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (!enabled) return _C.containerHighest; // bloqueado: gris
              if (states.contains(WidgetState.disabled)) return _C.primaryContainer.withValues(alpha: 0.7);
              if (states.contains(WidgetState.pressed)) return _C.primary;
              return _C.primaryContainer;
            }),
            foregroundColor: WidgetStatePropertyAll(contentColor),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(0),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Guardar preferencias y continuar',
                        style: _T.labelLg(contentColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Symbols.arrow_forward, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

// ===================== Tokens del mockup =====================

const _shadowSm = [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))];

/// Colores del sistema "Italian Industrial Precision" (DESIGN.md del colaborador).
abstract final class _C {
  static const surface = Color(0xFFF9F9F9);
  static const surfaceBright = Color(0xFFF9F9F9);
  static const surfaceDim = Color(0xFFDADADA);
  static const white = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF1A1C1C);
  static const secondary = Color(0xFF5F5E5E);
  static const secondaryContainer = Color(0xFFE5E2E1);
  static const primary = Color(0xFFB3011A);
  static const primaryContainer = Color(0xFFD7282F);
  static const primaryFixed = Color(0xFFFFDAD7);
  static const primaryFixedDim = Color(0xFFFFB3AD);
  static const onPrimaryFixedVariant = Color(0xFF930013);
  static const disabledText = Color(0xFF8A8A8A); // "Text Secondary / inactive" del DESIGN.md
  static const inverseSurface = Color(0xFF2F3131);
  static const inverseOnSurface = Color(0xFFF1F1F1);
  static const containerLow = Color(0xFFF3F3F3);
  static const container = Color(0xFFEEEEEE);
  static const containerHigh = Color(0xFFE8E8E8);
  static const containerHighest = Color(0xFFE2E2E2);
  static const error = Color(0xFFBA1A1A);
}

/// Escala tipográfica Inter del mockup. En Flutter, la altura de línea es un
/// multiplicador (30 px / 24 px) y el espaciado va en píxeles (em × tamaño).
abstract final class _T {
  static TextStyle _inter(double size, double lineHeight, FontWeight weight, double trackingEm, Color color) =>
      GoogleFonts.inter(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: trackingEm * size,
        color: color,
      );

  static TextStyle headlineLg([Color c = _C.onSurface]) => _inter(24, 30, FontWeight.w600, -0.015, c);
  static TextStyle headlineSm([Color c = _C.onSurface]) => _inter(18, 24, FontWeight.w600, 0, c);
  static TextStyle labelLg([Color c = _C.onSurface]) => _inter(14, 18, FontWeight.w600, 0.01, c);
  static TextStyle labelMd([Color c = _C.onSurface]) => _inter(12, 16, FontWeight.w600, 0.02, c);
  static TextStyle labelSm([Color c = _C.onSurface]) => _inter(11, 14, FontWeight.w500, 0.03, c);
  static TextStyle bodyMd([Color c = _C.onSurface]) => _inter(14, 20, FontWeight.w400, 0, c);
  static TextStyle bodySm([Color c = _C.onSurface]) => _inter(13, 18, FontWeight.w400, 0, c);
  static TextStyle caption([Color c = _C.onSurface]) => _inter(10, 12, FontWeight.w500, 0.04, c);
}
