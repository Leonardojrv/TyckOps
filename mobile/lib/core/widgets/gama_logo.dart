// ¿PARA QUÉ SIRVE?
//   Muestra el logo oficial de GA.MA Italy Professional.
//
// ¿QUÉ HACE?
//   Dibuja la imagen assets/images/gama_logo.png al alto que le pidas, sin
//   deformarla.
//
// ¿CÓMO LO CAMBIO?
//   Para cambiar el logo de TODA la app, reemplaza el archivo de imagen (mismo
//   nombre). Ideal: uno de 1000 px o más, para que no se vea borroso.

import 'package:flutter/material.dart';

/// Logo oficial de GA.MA Italy Professional.
///
/// Úsalo en cualquier pantalla que necesite el logo (login, encabezados, etc.).
/// La imagen está en assets/images/gama_logo.png: para cambiar el logo de
/// toda la app basta con reemplazar ese archivo (idealmente por uno en alta
/// resolución, de 1000 px o más de ancho, para que no se vea borroso).
class GamaLogo extends StatelessWidget {
  const GamaLogo({super.key, this.height = 72});

  /// Alto en pantalla; el ancho se ajusta solo para no deformar el logo.
  final double height;

  static const assetPath = 'assets/images/gama_logo.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'GA.MA Italy Professional',
      image: true,
      child: Image.asset(
        assetPath,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium, // suaviza los bordes al agrandar
      ),
    );
  }
}
