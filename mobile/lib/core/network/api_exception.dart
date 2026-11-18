// ¿PARA QUÉ SIRVE?
//   Es la forma en que la app entiende los errores del servidor.
//
// ¿QUÉ HACE?
//   Traduce cualquier falla (sin internet, sesión vencida, datos inválidos...) a un
//   mensaje que una persona entiende, sin mostrar detalles técnicos que le den
//   pistas a un atacante.
//
// ¿CÓMO LO CAMBIO?
//   Si quieres cambiar el texto de un error común (por ejemplo, sin conexión), se
//   hace aquí. Los mensajes propios del servidor se muestran tal cual.

import 'package:dio/dio.dart';

/// Error de la API ya traducido a un mensaje que el usuario entiende.
///
/// Seguridad: nunca mostramos el detalle técnico de un fallo (rutas internas,
/// consultas a la base de datos, etc.), porque le daría pistas a un atacante.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code; // código del backend, por ejemplo "CONTRASENA_ACTUAL_INCORRECTA"

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
    final serverError = _serverError(error.response?.data);
    return ApiException(
      serverError?.message ?? _defaultMessage(status),
      statusCode: status,
      code: serverError?.code,
    );
  }

  /// Cuando algo falla, el servidor responde con un código y un mensaje
  /// escrito para la persona (por ejemplo: {"error": {"message": "..."}}).
  /// Ese mensaje se muestra tal cual.
  static ({String? code, String message})? _serverError(Object? data) {
    if (data is! Map) return null;
    final error = data['error'];
    if (error is! Map || error['message'] is! String) return null;
    return (code: error['code'] as String?, message: error['message'] as String);
  }

  static String _defaultMessage(int? status) => switch (status) {
        400 => 'Los datos enviados no son válidos.',
        401 => 'Tu sesión expiró. Inicia sesión nuevamente.',
        403 => 'No tienes permiso para realizar esta acción.',
        404 => 'No se encontró lo solicitado.',
        409 => 'La acción no se puede realizar en el estado actual.',
        413 => 'El archivo es demasiado grande.',
        429 => 'Demasiados intentos. Espera unos minutos.',
        final int code when code >= 500 => 'Error del servidor. Intenta más tarde.',
        _ => 'Ocurrió un error inesperado.',
      };

  @override
  String toString() => message;
}
