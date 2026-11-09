import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/network/api_exception.dart';

DioException _response(int status, Object? body) {
  final request = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  group('Errores de la API', () {
    test('muestra el mensaje y el código que manda el backend', () {
      final error = ApiException.fromDio(_response(400, {
        'success': false,
        'error': {
          'code': 'CONTRASENA_ACTUAL_INCORRECTA',
          'message': 'La contraseña temporal actual no es correcta.',
        },
      }));
      expect(error.message, 'La contraseña temporal actual no es correcta.');
      expect(error.code, 'CONTRASENA_ACTUAL_INCORRECTA');
      expect(error.statusCode, 400);
    });

    test('sin mensaje del servidor usa un texto genérico', () {
      expect(ApiException.fromDio(_response(500, '<html>stack trace</html>')).message,
          'Error del servidor. Intenta más tarde.');
      expect(ApiException.fromDio(_response(429, null)).message,
          'Demasiados intentos. Espera unos minutos.');
    });
  });
}
