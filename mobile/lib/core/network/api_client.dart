// ¿PARA QUÉ SIRVE?
//   Es el único "cartero" de la app: todo lo que se pide al servidor pasa por aquí.
//
// ¿QUÉ HACE?
//   En cada petición agrega tu sesión (el token), si el servidor dice que la sesión
//   venció te devuelve al login, y convierte cualquier error en un mensaje claro.
//
// ¿CÓMO LO CAMBIO?
//   Si necesitas un tipo de petición nueva (por ejemplo, DELETE), agrégala aquí para
//   que también lleve el token y el manejo de errores.

import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Cliente HTTP único de la app. Todos los repositorios (auth, tickets,
/// dashboard...) lo usan para hablar con el backend.
///
/// Hace tres cosas automáticamente en cada petición:
/// 1. Agrega tu sesión (el token) a cada pedido.
/// 2. Si el servidor responde que la sesión venció o no es válida (error 401),
///    borra el token y te devuelve al login.
/// 3. Convierte cualquier error en un mensaje claro para la persona.
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
          // Si el pedido ya trae su propia llave (por ejemplo, el pase de la
          // verificación en dos pasos), se respeta; si no, va la de la sesión.
          if (!options.headers.containsKey('Authorization')) {
            final token = await tokenStorage.readToken();
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
          }
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

  /// Descarga un archivo (por ejemplo, la foto de un ticket) como bytes.
  /// Se usa para fotos privadas: viajan con el token igual que el resto y
  /// quedan solo en memoria, nunca en el disco del teléfono.
  /// [expectedTypePrefix] evita mostrar algo que no sea lo esperado
  /// (si el servidor no responde una imagen, se rechaza).
  Future<Uint8List> getBytes(String path, {String expectedTypePrefix = 'image/'}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      final type = response.headers.value(Headers.contentTypeHeader) ?? '';
      if (!type.startsWith(expectedTypePrefix) || response.data == null) {
        throw const ApiException('El archivo recibido no es válido.');
      }
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// [bearer]: llave especial solo para este pedido (la usa la verificación en
  /// dos pasos, que todavía no tiene sesión). Nunca se guarda en el teléfono.
  Future<T> post<T>(String path, {Object? body, String? bearer}) => _send(() => _dio.post<T>(
        path,
        data: body,
        options: bearer == null ? null : Options(headers: {'Authorization': 'Bearer $bearer'}),
      ));

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
