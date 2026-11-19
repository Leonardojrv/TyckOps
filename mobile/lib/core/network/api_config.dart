// ¿PARA QUÉ SIRVE?
//   Dice a qué servidor se conecta la app.
//
// ¿QUÉ HACE?
//   Lee la dirección del servidor al compilar (no va escrita fija en el código) y
//   si se usa el modo de prueba sin servidor.
//
// ¿CÓMO LO CAMBIO?
//   Para apuntar a otro servidor no edites este archivo: usa
//   --dart-define=API_BASE_URL=... al ejecutar o compilar.

import 'package:flutter/foundation.dart';

/// Configuración de la API.
///
/// La URL NO se escribe fija en el código: se pasa al compilar con
/// --dart-define. Ejemplos:
///
///   flutter run                                         → usa el valor por defecto
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
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

  /// Para trabajar sin backend: flutter run --dart-define=FAKE_AUTH=true
  static const useFakeAuth = bool.fromEnvironment('FAKE_AUTH');

  /// Cifrado app → backend: una versión release (la que se instala en los
  /// teléfonos) solo puede hablar con el servidor por https. Si alguien compila
  /// con una URL http, la app se detiene al abrir en vez de enviar contraseñas
  /// y fotos sin cifrar. En depuración (flutter run) se permite http local.
  static void validarCifrado({bool esRelease = kReleaseMode}) {
    if (esRelease && !useFakeAuth && !baseUrl.startsWith('https://')) {
      throw StateError(
        'API_BASE_URL debe usar https:// en una versión release (recibido: $baseUrl).',
      );
    }
  }

  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);
}
