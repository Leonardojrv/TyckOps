// ¿PARA QUÉ SIRVE?
//   Define los 4 tipos de avería del reporte y la foto elegida.
//
// ¿QUÉ HACE?
//   Guarda el código que se envía al servidor, el texto, el ícono de cada categoría
//   y los límites del formulario (largos y 5 MB de foto).
//
// ¿CÓMO LO CAMBIO?
//   Para agregar una categoría nueva, súmala aquí Y en el servidor
//   (tickets.schema.js). Los límites deben coincidir con los del servidor.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Tipos de avería del reporte (RF-04). [apiValue] es lo que viaja al servidor.
enum FaultCategory {
  electrical('ELECTRICA', 'Eléctrica', 'Enchufes, tableros', 'Electricidad y Tableros', Symbols.electric_bolt),
  bathrooms('BANOS', 'Baños', 'Grifería, fugas', 'Sanitarios y Grifería', Symbols.water_drop),
  airConditioning('AIRE_ACONDICIONADO', 'Aire acond.', 'HVAC, climatización', 'Climatización HVAC', Symbols.mode_fan),
  furniture('INMOBILIARIO', 'Inmobiliario', 'Sillas, Escritorio', 'Mobiliario y Cerrajería', Symbols.chair);

  const FaultCategory(this.apiValue, this.label, this.examples, this.headline, this.icon);

  final String apiValue;
  final String label; // texto de la tarjeta
  final String examples; // subtítulo de la tarjeta
  final String headline; // texto rojo junto a "1. Tipo de avería"
  final IconData icon;
}

/// Límites del formulario. El servidor valida lo mismo (no confiar solo en la app).
abstract final class ReportLimits {
  static const minLocation = 3;
  static const maxLocation = 150;
  static const minDescription = 10;
  static const maxDescription = 250;
  static const maxPhotoBytes = 5 * 1024 * 1024; // 5 MB
}

/// Foto elegida, ya leída en memoria (para la miniatura y el envío).
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name; // solo para mostrar; el servidor pone su propio nombre

  /// Tipo real según los primeros bytes (igual que el servidor).
  String? get mimeType {
    final b = bytes;
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    return null;
  }
}
