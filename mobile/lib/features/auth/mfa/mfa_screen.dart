// ¿PARA QUÉ SIRVE?
//   Es la pantalla "Verificación en Dos Pasos" (T8): después de la contraseña,
//   pide el código de 6 dígitos que llegó al correo corporativo.
//
// ¿QUÉ HACE?
//   Muestra a qué correo se envió el código, las 6 casillas, la cuenta regresiva
//   de 3 minutos y el botón "Reenviar código". Si el código es correcto entra a
//   la app; si no, explica por qué (incorrecto, vencido o demasiados intentos).
//
// ¿CÓMO LO CAMBIO?
//   La lógica está en mfa_controller.dart y las casillas en otp_code_field.dart
//   (las dos sirven también para el administrador en la T12). Aquí solo está el
//   diseño del mockup login/verificaci_n_de_seguridad_mfa_colaborador.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/user_role.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../worker/worker_tokens.dart';
import '../auth_session.dart';
import 'mfa_controller.dart';
import 'otp_code_field.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

// Colores propios de este mockup (la tarjeta oscura de arriba).
const _heroBg = Color(0xFF20232A);
const _heroChipBg = Color(0xFF462327);
const _heroDot = Color(0xFFB3011A);
const _heroPillBg = Color(0xFF373B43);
const _heroLock = Color(0xFFFFB3AD);
const _cardBorder = Color(0xFFE2E2E2);

class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key, required this.session, required this.authRepository});

  final AuthSession session;
  final AuthRepository authRepository;

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  late final MfaController _mfa = MfaController(session: widget.session, repository: widget.authRepository);
  final _code = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // El aviso rojo se borra cuando la persona vuelve a escribir (no cuando la
    // app vacía las casillas tras un código rechazado, para que lea el motivo).
    _code.addListener(() {
      if (_code.text.isNotEmpty) _mfa.clearError();
    });
    // El teclado numérico se abre solo al llegar a la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _mfa.dispose();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    final ok = await _mfa.verify(_code.text);
    // Si el código fue rechazado, se borra para escribirlo de nuevo.
    if (!ok && mounted && _mfa.codeRejected) {
      _code.clear();
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    await _mfa.resend();
    if (!mounted) return;
    _code.clear();
    _focus.requestFocus();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // El botón "atrás" de Android equivale a "Cancelar y volver al inicio de sesión".
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _mfa.cancel();
      },
      child: Scaffold(
        backgroundColor: _C.surface,
        appBar: _Header(onBack: _mfa.cancel),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListenableBuilder(
            listenable: _mfa,
            builder: (context, _) {
              final challenge = _mfa.challenge;
              if (challenge == null) return const SizedBox.shrink(); // ya se canceló
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 16),
                  _AccountCard(email: challenge.email, role: challenge.role),
                  const SizedBox(height: 16),
                  _CodeCard(
                    controller: _code,
                    focusNode: _focus,
                    mfa: _mfa,
                    onCompleted: (_) => _verify(),
                    onPasted: () => _toast('Código pegado.'),
                    onResend: _resend,
                  ),
                  const SizedBox(height: 24),
                  _PrimaryButton(loading: _mfa.verifying, onPressed: _mfa.verifying ? null : _verify),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _mfa.verifying ? null : _mfa.cancel,
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.containerHigh,
                        foregroundColor: _C.onSurface,
                        disabledBackgroundColor: _C.containerHigh,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Cancelar y volver al inicio de sesión', style: _T.labelLg().copyWith(fontWeight: FontWeight.w500)),
                    ),
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

// ===================== Encabezado =====================

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
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Volver',
                onPressed: onBack,
                constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                icon: const Icon(Symbols.arrow_back, size: 24, color: _C.onSurface),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Verificación En Dos Pasos',
                  overflow: TextOverflow.ellipsis,
                  style: _T.headlineSm().copyWith(letterSpacing: -0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Tarjeta oscura =====================

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _heroBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: workerShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _heroChipBg, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: _heroDot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GA.MA ITALY PROFESSIONAL',
                      style: _T.caption(_C.white).copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'TYCKOPS',
                style: _T.caption(_C.white).copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.6),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Verificación en Dos Pasos',
            style: _T.headlineLg(_C.white).copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            'Seguridad de Credenciales · GA.MA Chile',
            style: _T.bodyMd(_C.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: _heroPillBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.lock, size: 17, color: _heroLock),
                const SizedBox(width: 8),
                Text(
                  'Código MFA de 6 dígitos',
                  style: _T.labelMd(_C.white).copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Tarjeta de la cuenta =====================

/// Muestra a qué correo se envió el código. Es el correo con que se inició
/// sesión (hoy colaborador@gamaitaly.cl); cuando haya correos reales, cada
/// persona verá el suyo sin cambiar nada aquí.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email, required this.role});

  final String email;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final roleLabel = role == UserRole.admin ? 'Administrador' : 'Colaborador';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: workerShadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Symbols.shield, size: 22, color: _C.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: _T.labelLg().copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                Text('Sesión de $roleLabel en curso', style: _T.bodySm(_C.secondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Symbols.check_circle, size: 26, color: _C.primaryContainer),
        ],
      ),
    );
  }
}

// ===================== Tarjeta del código =====================

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.controller,
    required this.focusNode,
    required this.mfa,
    required this.onCompleted,
    required this.onPasted,
    required this.onResend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final MfaController mfa;
  final ValueChanged<String> onCompleted;
  final VoidCallback onPasted;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: workerShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: _C.primaryContainer), // franja roja de arriba
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _C.errorContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Symbols.security, fill: 1, size: 20, color: _C.primaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Ingresa tu código', style: _T.headlineSm().copyWith(fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        'SEGURIDAD',
                        style: _T.labelSm(_C.secondary).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Ingresa el código de 6 dígitos enviado a tu correo corporativo para completar el acceso seguro al sistema.',
                    style: _T.bodyMd(_C.onSurfaceVariant).copyWith(height: 1.6),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: OtpCodeField(
                      controller: controller,
                      focusNode: focusNode,
                      hasError: mfa.codeRejected,
                      enabled: !mfa.verifying,
                      onCompleted: onCompleted,
                      onPasted: onPasted,
                      style: OtpFieldStyle(
                        digitStyle: _T.headlineLg().copyWith(fontWeight: FontWeight.w700, height: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (mfa.error != null)
                  _Message(icon: Symbols.error, text: mfa.error!, color: _C.error)
                else if (mfa.info != null)
                  _Message(icon: Symbols.mark_email_read, text: mfa.info!, color: _C.secondary)
                else
                  Text(
                    'Presiona en tu teclado para completar los dígitos restantes',
                    textAlign: TextAlign.center,
                    style: _T.caption(_C.secondary).copyWith(letterSpacing: 0),
                  ),
                const SizedBox(height: 20),
                Center(child: _Countdown(text: mfa.countdown, expired: mfa.expired)),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    height: 40,
                    child: FilledButton(
                      onPressed: mfa.canResend ? onResend : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.container,
                        foregroundColor: _C.onSurface,
                        disabledBackgroundColor: _C.container,
                        disabledForegroundColor: _C.secondary.withValues(alpha: 0.6),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          mfa.resending
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Symbols.refresh, size: 18),
                          const SizedBox(width: 8),
                          Text('Reenviar código', style: _T.labelMd()),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mfa.canResend ? 'Ya puedes solicitar un código nuevo' : 'Podrás solicitar uno nuevo al finalizar el tiempo',
                  textAlign: TextAlign.center,
                  style: _T.caption(_C.secondary.withValues(alpha: 0.8)).copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Symbols.info, size: 18, color: _C.secondary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Si el tiempo de 3 minutos expira, el código actual quedará invalidado por seguridad y deberás generar uno nuevo.',
                          style: _T.caption(_C.onSurfaceVariant).copyWith(height: 1.6, letterSpacing: 0),
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

/// "El código expira en 02:59" con el reloj rojo.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.text, required this.expired});

  final String text;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: expired ? 'El código venció' : 'El código expira en $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _C.containerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.timer, size: 20, color: _C.primaryContainer),
            const SizedBox(width: 8),
            Text(
              expired ? 'El código venció' : 'El código expira en ',
              style: _T.bodyMd().copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
            ),
            if (!expired)
              Text(
                text,
                style: _T.bodyMd(_C.primaryContainer).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, textAlign: TextAlign.center, style: _T.bodySm(color))),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: workerShadowSm),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _C.primaryContainer,
            foregroundColor: _C.white,
            disabledBackgroundColor: _C.primaryContainer.withValues(alpha: 0.75),
            disabledForegroundColor: _C.white,
            overlayColor: const Color(0xFF930013),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: loading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _C.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Verificar código', style: _T.labelLg(_C.white)),
                    const SizedBox(width: 8),
                    const Icon(Symbols.arrow_forward, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}
