// ¿PARA QUÉ SIRVE?
//   Es el chip del rol que va arriba a la derecha en el encabezado:
//   "Colaborador" o "Administrador".
//
// ¿QUÉ HACE?
//   Al tocarlo abre un pequeño menú con "Cerrar sesión" (los mockups no tienen
//   otro lugar para hacerlo). Es el mismo para el colaborador y el
//   administrador, así se comportan igual.
//
// ¿CÓMO LO CAMBIO?
//   Para agregar otra opción de la cuenta (por ejemplo, "Mi perfil"), súmala en
//   itemBuilder.

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/worker/worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

class AccountRoleChip extends StatelessWidget {
  const AccountRoleChip({super.key, required this.label, required this.onSignOut});

  final String label; // "Colaborador" o "Administrador"
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Opciones de la cuenta',
      position: PopupMenuPosition.under,
      color: _C.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: onSignOut,
          child: Row(
            children: [
              const Icon(Symbols.logout, size: 20, color: _C.onSurface),
              const SizedBox(width: 12),
              Text('Cerrar sesión', style: _T.bodyMd()),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _C.container, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: _T.labelSm(_C.secondary).copyWith(letterSpacing: -0.1)),
      ),
    );
  }
}
