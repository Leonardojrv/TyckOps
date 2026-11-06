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

  /// RF-09: solo se puede cancelar mientras está Recibido.
  /// Ojo: esto solo oculta el botón. El servidor debe validarlo igual.
  bool get canBeCancelled => this == TicketStatus.received;

  /// RF-07: el motivo solo se muestra en los rechazados.
  bool get showsRejectionReason => this == TicketStatus.rejected;
}
