/// Configuración de la API.
///
/// La URL NO se escribe fija en el código: se pasa al compilar con
/// --dart-define. Ejemplos:
///
///   flutter run                                         → usa el valor por defecto
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000/api
///   flutter build apk --dart-define=API_BASE_URL=https://api.ejemplo.cl/api
///
/// 10.0.2.2 es la dirección con la que el emulador de Android llega al
/// "localhost" de tu computador (donde corre el backend de Moisés).
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);
}
