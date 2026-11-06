import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/routes.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_session.dart';

/// Login único (RF-01, RF-11 adm). Mockup: docs/mockups/login/login_de_administrador
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session, required this.authRepository});

  final AuthSession session;
  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // GlobalKey: permite validar todos los campos del formulario de una vez.
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  // Los controllers ocupan memoria: se liberan cuando la pantalla se cierra.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus(); // esconde el teclado
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final result = await widget.authRepository.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Al iniciar sesión, el router redirige solo al home del rol.
      await widget.session.signIn(result.user, result.token);
    } on ApiException catch (e) {
      _passwordController.clear(); // seguridad: no dejar la clave escrita
      _showMessage(e.message);
    } finally {
      // "mounted" = la pantalla sigue existiendo. Si ya navegamos a otra,
      // no se puede llamar a setState.
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          // Permite hacer scroll cuando aparece el teclado.
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          child: Column(
            children: [
              _GamaLogo(
                // Solo en debug: mantener presionado el logo abre la galería.
                onLongPress: kDebugMode ? () => context.push(Routes.devComponents) : null,
              ),
              const SizedBox(height: 16),
              const _SecureBadge(),
              const SizedBox(height: 12),
              Text('Portal Corporativo', style: AppTypography.headlineLarge.copyWith(fontSize: 24, height: 30 / 24)),
              const SizedBox(height: 4),
              Text(
                'Servicios Generales & Mantenimiento Interno',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(fontSize: 13, color: _secondary),
              ),
              const SizedBox(height: 36),
              _FormCard(
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _DomainNotice(),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Correo corporativo',
                          trailingLabel: 'Chile HQ',
                          controller: _emailController,
                          hint: 'ejemplo@gamaitaly.cl',
                          prefixIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: Validators.corporateEmail,
                          enabled: !_loading,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 15, color: _secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Tu perfil se detecta automáticamente con tu cuenta corporativa.',
                                style: AppTypography.bodySmall.copyWith(fontSize: 11, color: _secondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Contraseña',
                          controller: _passwordController,
                          hint: '••••••••••••',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: (v) => Validators.required(v, field: 'La contraseña'),
                          enabled: !_loading,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _showMessage('Para restablecer tu contraseña, contacta a Soporte TI.'),
                            icon: const Icon(Icons.history, size: 17),
                            label: const Text('¿Olvidaste tu contraseña?'),
                            style: TextButton.styleFrom(
                              foregroundColor: _secondary,
                              textStyle: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _LoginButton(loading: _loading, onPressed: _submit),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

// Colores específicos del mockup de login (tokens de Stitch).
const _secondary = Color(0xFF5F5E5E); // "secondary"
const _brandRed = Color(0xFFB3011A); // "primary": botón y punto del logo
const _cardBorder = Color(0xFFE9E8E8); // "surface-container-high"
const _noticeBg = Color(0xFFF5F3F3); // "surface-container-low"
const _badgeBg = Color(0xFFEFEDED); // "surface-container"

class _GamaLogo extends StatelessWidget {
  const _GamaLogo({this.onLongPress});

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final letters = AppTypography.headlineLarge.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
      height: 1,
    );
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Semantics(
          label: 'GA.MA Italy Professional',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'GA', style: letters),
                TextSpan(text: '.', style: letters.copyWith(color: _brandRed, fontSize: 28)),
                TextSpan(text: 'MA', style: letters),
              ])),
              const SizedBox(height: 4),
              Text(
                'ITALY PROFESSIONAL',
                style: AppTypography.labelSmall.copyWith(fontSize: 8, letterSpacing: 2, color: _secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: _badgeBg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: _brandRed, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'ACCESO SEGURO',
            style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600, color: _secondary),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta blanca con la franja roja de 4 px arriba.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    // Los inputs del login son blancos con borde (no grises): se cambia el
    // tema solo para esta tarjeta.
    final theme = Theme.of(context);
    final whiteInputs = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cardBorder),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: _cardBorder),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: AppColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 4, color: AppColors.red),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Theme(data: whiteInputs, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainNotice extends StatelessWidget {
  const _DomainNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _noticeBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 20, color: _brandRed),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dominio corporativo requerido',
                  style: AppTypography.labelMedium.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Por favor utiliza tu correo corporativo (@gamaitaly.cl).',
                  style: AppTypography.bodySmall.copyWith(color: _secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: loading
            ? null
            : () {
                HapticFeedback.lightImpact(); // pequeña vibración al tocar
                onPressed();
              },
        style: FilledButton.styleFrom(
          backgroundColor: _brandRed,
          disabledBackgroundColor: _brandRed.withValues(alpha: 0.7),
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Iniciar sesión'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_outlined, size: 16, color: _secondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'ACCESO EXCLUSIVO PARA PERSONAL GA.MA CHILE',
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Plataforma Interna de Operaciones & Servicios de Infraestructura',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(fontSize: 11, color: _secondary.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}
