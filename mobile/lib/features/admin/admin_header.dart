// ¿PARA QUÉ SIRVE?
//   Es el encabezado de las pantallas del administrador (T13): "SERVICIOS
//   GENERALES" + el título y, a la derecha, el chip "Administrador".
//
// ¿QUÉ HACE?
//   Dibuja la franja superior igual que en los mockups del administrador. El
//   chip "Administrador" ofrece "Cerrar sesión" al tocarlo (igual que el chip
//   "Colaborador"). Si se le pasa onBack, muestra la flecha para volver.
//
// ¿CÓMO LO CAMBIO?
//   Los colores y letras vienen de worker_tokens.dart (mismo sistema de diseño).

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/widgets/account_role_chip.dart';
import '../worker/worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

class AdminHeader extends StatelessWidget implements PreferredSizeWidget {
  const AdminHeader({super.key, required this.title, required this.onSignOut, this.trailing, this.onBack});

  final String title;
  final Future<void> Function() onSignOut; // lo usa el chip "Administrador"
  final Widget? trailing;
  final VoidCallback? onBack;

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
            padding: EdgeInsets.only(left: onBack == null ? 16 : 4, right: 16),
            child: Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: onBack,
                    icon: const Icon(Symbols.arrow_back, size: 24, color: _C.onSurface),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SERVICIOS GENERALES', style: _T.labelSm(_C.secondary).copyWith(letterSpacing: 0.55)),
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: _T.headlineSm().copyWith(fontWeight: FontWeight.w700, height: 1.25),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
                // Igual que el colaborador: tocarlo ofrece "Cerrar sesión".
                AccountRoleChip(label: 'Administrador', onSignOut: onSignOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla del administrador que se construye en otra tarea: ya tiene su
/// encabezado (con "Administrador" para cerrar sesión) y, si corresponde, la
/// flecha para volver.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key, required this.title, required this.task, required this.onSignOut, this.onBack});

  final String title;
  final String task; // en qué tarea se desarrolla (por ejemplo, "T14")
  final Future<void> Function() onSignOut;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AdminHeader(title: title, onSignOut: onSignOut, onBack: onBack),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.construction, size: 36, color: _C.secondary),
              const SizedBox(height: 12),
              Text('Pantalla en construcción', style: _T.labelLg()),
              const SizedBox(height: 4),
              Text('Se desarrolla en la $task', style: _T.bodySm(_C.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}
