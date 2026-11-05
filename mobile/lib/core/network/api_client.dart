import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Cliente HTTP único de la app. Todos los repositorios (auth, tickets,
/// dashboard...) lo usan para hablar con el backend.
///
/// Hace tres cosas automáticamente en cada petición:
/// 1. Agrega el token: `Authorization: Bearer <token>`.
/// 2. Si el servidor responde 401 (token vencido o inválido), borra el token
///    y avisa con [onUnauthorized] para volver al login.
/// 3. Convierte cualquier error en un [ApiException] con un mensaje claro.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    this.onUnauthorized,
    String? baseUrl,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.readToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await tokenStorage.clear();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final void Function()? onUnauthorized;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? body}) =>
      _send(() => _dio.post<T>(path, data: body));

  Future<T> patch<T>(String path, {Object? body}) =>
      _send(() => _dio.patch<T>(path, data: body));

  /// Para enviar archivos (fotos del reporte en la T6, archivo plano en la
  /// T15). [onProgress] recibe un valor entre 0 y 1 para la barra de progreso.
  Future<T> upload<T>(
    String path,
    FormData form, {
    void Function(double progress)? onProgress,
  }) =>
      _send(() => _dio.post<T>(
            path,
            data: form,
            onSendProgress: (sent, total) {
              if (total > 0) onProgress?.call(sent / total);
            },
          ));

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
