import 'package:dio/dio.dart';

/// Error de la API ya traducido a un mensaje que el usuario entiende.
///
/// Seguridad: nunca mostramos al usuario el error técnico completo (rutas,
/// SQL, stack traces), porque le da pistas a un atacante sobre el servidor.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('El servidor tardó demasiado en responder. Intenta nuevamente.');
      case DioExceptionType.connectionError:
        return const ApiException('No hay conexión con el servidor. Revisa tu internet.');
      default:
        break;
    }

    final status = error.response?.statusCode;
    final data = error.response?.data;
    // Si el backend manda {"message": "..."} con un texto pensado para el
    // usuario (por ejemplo, "Solo se puede cancelar en estado Recibido"),
    // se muestra ese texto.
    final serverMessage =
        data is Map && data['message'] is String ? data['message'] as String : null;

    return ApiException(serverMessage ?? _defaultMessage(status), statusCode: status);
  }

  static String _defaultMessage(int? status) => switch (status) {
        400 => 'Los datos enviados no son válidos.',
        401 => 'Tu sesión expiró. Inicia sesión nuevamente.',
        403 => 'No tienes permiso para realizar esta acción.',
        404 => 'No se encontró lo solicitado.',
        409 => 'La acción no se puede realizar en el estado actual.',
        413 => 'El archivo es demasiado grande.',
        final int code when code >= 500 => 'Error del servidor. Intenta más tarde.',
        _ => 'Ocurrió un error inesperado.',
      };

  @override
  String toString() => message;
}
