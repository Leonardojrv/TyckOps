// ¿PARA QUÉ SIRVE?
//   Envía el reporte de una falla al servidor (T6).
//
// ¿QUÉ HACE?
//   Arma el formulario con la categoría, la ubicación, la descripción y la foto
//   (si hay), y devuelve el ticket recién creado.
//
// ¿CÓMO LO CAMBIO?
//   Si el formulario suma un campo, agrégalo aquí y en el servidor. El nombre de la
//   foto lo pone el servidor; nunca se manda el del teléfono.
//
//   Tiempo límite: antes de reportar se pide un permiso de creación
//   (startSession). Dura lo que diga el servidor (3 minutos) y se manda al
//   enviar en la cabecera X-Sesion-Creacion. Si venció, el servidor responde
//   TIEMPO_CREACION_EXPIRADO y el ticket no se guarda.

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/fault_category.dart';
import '../models/ticket.dart';
import '../models/ticket_status.dart';

/// Código con que el servidor avisa que pasaron los 3 minutos para crear el ticket.
const reportTimeExpiredCode = 'TIEMPO_CREACION_EXPIRADO';

/// Permiso de creación que entrega el servidor al abrir "Reportar falla".
class ReportSession {
  const ReportSession({required this.token, required this.duration});

  final String token;

  /// Cuánto dura el permiso según el servidor. Se cuenta desde que llega al
  /// teléfono (no se usa la hora del teléfono, que puede estar desfasada).
  final Duration duration;
}

/// RF-04: enviar un reporte de falla con su foto.
abstract class ReportRepository {
  /// Pide al servidor el permiso (con tiempo límite) para crear un ticket.
  Future<ReportSession> startSession();

  Future<Ticket> create({
    required String sessionToken,
    required FaultCategory category,
    required String location,
    required String description,
    PickedPhoto? photo, // opcional
    void Function(double progress)? onProgress,
  });
}

class ApiReportRepository implements ReportRepository {
  ApiReportRepository(this._api);

  final ApiClient _api;

  @override
  Future<ReportSession> startSession() async {
    final body = await _api.post<Map<String, dynamic>>('/tickets/sesion-creacion');
    final data = body['data'];
    final token = data is Map ? data['token'] : null;
    final seconds = data is Map ? data['duracionSegundos'] : null;
    if (token is! String || token.isEmpty || seconds is! num || seconds <= 0) {
      throw const FormatException('Respuesta de sesión de creación inválida');
    }
    return ReportSession(token: token, duration: Duration(seconds: seconds.toInt()));
  }

  @override
  Future<Ticket> create({
    required String sessionToken,
    required FaultCategory category,
    required String location,
    required String description,
    PickedPhoto? photo, // opcional
    void Function(double progress)? onProgress,
  }) async {
    final mime = photo?.mimeType;
    if (photo != null && mime == null) {
      throw const ApiException('La foto debe ser JPG o PNG.', statusCode: 415);
    }

    final form = FormData.fromMap({
      'categoria': category.apiValue,
      'ubicacion': location,
      'descripcion': description,
      // Nombre genérico: el nombre del archivo del teléfono no se envía.
      if (photo != null)
        'foto': MultipartFile.fromBytes(
          photo.bytes,
          filename: mime == 'image/png' ? 'foto.png' : 'foto.jpg',
          contentType: DioMediaType.parse(mime!),
        ),
    });
    final body = await _api.upload<Map<String, dynamic>>(
      '/tickets',
      form,
      onProgress: onProgress,
      headers: {'X-Sesion-Creacion': sessionToken},
    );
    final ticket = (body['data'] as Map?)?['ticket'];
    if (ticket is! Map) throw const FormatException('Respuesta de reporte inválida');
    return Ticket.fromJson(ticket.cast<String, dynamic>());
  }
}

/// Para usar la app sin backend (--dart-define=FAKE_AUTH=true).
class FakeReportRepository implements ReportRepository {
  int _next = 143;

  @override
  Future<ReportSession> startSession() async =>
      const ReportSession(token: 'fake', duration: Duration(minutes: 3));

  @override
  Future<Ticket> create({
    required String sessionToken,
    required FaultCategory category,
    required String location,
    required String description,
    PickedPhoto? photo, // opcional
    void Function(double progress)? onProgress,
  }) async {
    for (var i = 1; i <= 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      onProgress?.call(i / 5);
    }
    final n = _next++;
    return Ticket(
      id: 't-$n',
      code: 'REP-${n.toString().padLeft(4, '0')}',
      category: category.label == 'Aire acond.' ? 'Aire acondicionado' : category.label,
      title: description,
      status: TicketStatus.received,
      priority: null,
      location: location,
      createdAt: DateTime.now(),
    );
  }
}
