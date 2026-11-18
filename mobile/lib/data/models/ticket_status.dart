// ¿PARA QUÉ SIRVE?
//   Define los 8 estados por los que pasa un ticket.
//
// ¿QUÉ HACE?
//   Traduce el texto del servidor ("EN_PROCESO") al que ve la persona ("En
//   proceso") y responde preguntas como "¿sigue en curso?" o "¿se puede cancelar?".
//
// ¿CÓMO LO CAMBIO?
//   Si el equipo agrega un estado, súmalo aquí con su texto, y revisa los chips y la
//   línea de tiempo del detalle.

/// Los 8 estados del ciclo de vida del ticket
/// (docs/requerimientos/requerimientos-funcionales.md).
///
/// [apiValue] es el texto que viaja por la API. Hay que acordarlo con Moisés:
/// si el backend usa otros valores, se cambian solo aquí.
enum TicketStatus {
  received('RECIBIDO', 'Recibido'),
  inReview('EN_REVISION', 'En revisión'),
  approved('APROBADO', 'Aprobado'),
  rejected('RECHAZADO', 'Rechazado'),
  inProgress('EN_PROCESO', 'En proceso'),
  resolved('RESUELTO', 'Resuelto'),
  closed('CERRADO', 'Cerrado'),
  cancelled('CANCELADO', 'Cancelado');

  const TicketStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TicketStatus fromApi(String value) => TicketStatus.values.firstWhere(
        (s) => s.apiValue == value.toUpperCase(),
        orElse: () => throw FormatException('Estado de ticket desconocido: $value'),
      );

  /// El ticket sigue en atención (aún no termina): recibido, en revisión,
  /// aprobado o en proceso. Lo usan la lista, los filtros y el detalle.
  bool get isActiveStatus => switch (this) {
        TicketStatus.received || TicketStatus.inReview || TicketStatus.approved || TicketStatus.inProgress => true,
        _ => false,
      };

  /// RF-09: solo se puede cancelar mientras está Recibido.
  /// Ojo: esto solo oculta el botón. El servidor debe validarlo igual.
  bool get canBeCancelled => this == TicketStatus.received;

  /// RF-07: el motivo solo se muestra en los rechazados.
  bool get showsRejectionReason => this == TicketStatus.rejected;
}
