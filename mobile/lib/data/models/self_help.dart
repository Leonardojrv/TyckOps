// ¿PARA QUÉ SIRVE?
//   Son los datos de la asistencia de IA del colaborador (T10): la guía paso a
//   paso de los tickets de prioridad Baja y el resumen del ticket ORIGINAL
//   cuando el tuyo fue agrupado como duplicado.
//
// ¿QUÉ HACE?
//   Lee lo que manda el servidor (GET /tickets/:id/guia y el detalle) y lo deja
//   listo para las pantallas. Si algo viene raro, lo descarta en vez de mostrarlo.
//
// ¿CÓMO LO CAMBIO?
//   Si el servidor agrega un dato a la guía o al original, súmalo aquí y en su
//   fromJson.

import 'ticket_status.dart';

/// Lo que decide el colaborador al terminar la guía.
enum GuideAction {
  close('cerrar'), // "Cerrar ticket (Problema solucionado)"
  escalate('escalar'); // "Reportar a administración"

  const GuideAction(this.apiValue);

  final String apiValue; // va en la URL: /tickets/:id/guia/cerrar
}

/// Un paso de la guía: título en negrita y una explicación corta.
class GuideStep {
  const GuideStep({required this.title, this.detail = ''});

  final String title;
  final String detail;

  factory GuideStep.fromJson(Map<String, dynamic> json) => GuideStep(
        title: (json['titulo'] as String? ?? '').trim(),
        detail: (json['detalle'] as String? ?? '').trim(),
      );
}

/// La guía de autoayuda de un ticket (RF-10).
class SelfHelpGuide {
  const SelfHelpGuide({required this.id, required this.title, required this.steps, this.simulated = false});

  final String id;
  final String title;
  final List<GuideStep> steps;
  final bool simulated; // true mientras el servicio de IA no entregue la suya

  factory SelfHelpGuide.fromJson(Map<String, dynamic> json) => SelfHelpGuide(
        id: json['id'].toString(),
        title: (json['titulo'] as String? ?? '').trim(),
        simulated: json['origen'] == 'simulada',
        steps: [
          for (final item in (json['pasos'] as List?) ?? const [])
            if (item is Map) GuideStep.fromJson(item.cast<String, dynamic>()),
        ].where((s) => s.title.isNotEmpty).toList(growable: false),
      );
}

/// Lo que puedes ver del ticket ORIGINAL cuando el tuyo es un duplicado.
/// El servidor nunca manda quién lo reportó (ni nombre, ni correo, ni foto).
class DuplicateOriginal {
  const DuplicateOriginal({
    required this.code,
    required this.category,
    required this.title,
    required this.status,
    required this.location,
    required this.createdAt,
    this.mine = false,
  });

  final String code;
  final String category;
  final String title;
  final TicketStatus status;
  final String location;
  final DateTime createdAt; // en hora local
  final bool mine; // true si el original también lo reportaste tú

  factory DuplicateOriginal.fromJson(Map<String, dynamic> json) => DuplicateOriginal(
        code: json['code'] as String,
        category: json['category'] as String? ?? '',
        title: json['title'] as String? ?? '',
        status: TicketStatus.fromApi(json['status'] as String),
        location: json['location'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        mine: json['mine'] == true,
      );
}
