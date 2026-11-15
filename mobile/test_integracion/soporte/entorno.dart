// Soporte para las pruebas de integración de la app contra el backend REAL.
//
// - Levanta el backend (node src/server.js) en el puerto 3103, conectado a la
//   base de pruebas BDTyckOps_pruebas del Docker (nunca a la base real).
// - Recarga los datos de prueba antes de cada prueba.
// - Guarda el token en memoria (en las pruebas no hay Keystore/Keychain).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tyckops/core/network/token_storage.dart';

const puertoBackend = 3103;
const urlApi = 'http://127.0.0.1:$puertoBackend/api';

/// Mismos usuarios que backend/integracion/helpers/usuarios.js.
abstract final class Cuentas {
  static const colaboradorNuevo = ('colaborador.nuevo@gamaitaly.cl', 'ClaveTemporal1');
  static const adminNuevo = ('admin.nuevo@gamaitaly.cl', 'ClaveTemporal2');
  static const colaboradorActivo = ('colaborador.activo@gamaitaly.cl', 'ClaveActiva123');
  static const adminActivo = ('admin.activo@gamaitaly.cl', 'ClaveAdmin123');
  static const sinRolValido = ('invitado@gamaitaly.cl', 'ClaveInvitado1');
}

final _backendDir = Directory('${Directory.current.parent.path}${Platform.pathSeparator}backend');

Future<String> _node(List<String> args) async {
  final r = await Process.run('node', args, workingDirectory: _backendDir.path, runInShell: true);
  if (r.exitCode != 0) {
    throw StateError('node ${args.join(' ')} falló:\n${r.stdout}\n${r.stderr}');
  }
  return (r.stdout as String).trim();
}

/// Crea BDTyckOps_pruebas (si falta), aplica migraciones y carga los datos.
Future<void> prepararBase() => _node(['integracion/helpers/cli.js', 'preparar']);

/// Vuelve a dejar los usuarios de prueba en su estado inicial.
Future<void> reiniciarDatos() => _node(['integracion/helpers/cli.js', 'reiniciar']);

/// Consulta directa a PostgreSQL (vía Prisma del backend) para verificar
/// lo que quedó guardado después de usar la app.
Future<Map<String, dynamic>> usuarioEnBd(String email) async {
  final salida = await _node(['integracion/helpers/cli.js', 'usuario', email]);
  return jsonDecode(salida) as Map<String, dynamic>;
}

class BackendDePrueba {
  Process? _proceso;

  Future<void> iniciar() async {
    final url = await _node(['integracion/helpers/cli.js', 'url']);
    final proceso = await Process.start(
      'node',
      ['src/server.js'],
      workingDirectory: _backendDir.path,
      environment: {'PORT': '$puertoBackend', 'DATABASE_URL': url, 'NODE_ENV': 'development'},
      runInShell: true,
    );
    _proceso = proceso;

    final listo = Completer<void>();
    final log = StringBuffer();
    proceso.stdout.transform(utf8.decoder).listen((linea) {
      log.write(linea);
      if (linea.contains('escuchando') && !listo.isCompleted) listo.complete();
    });
    proceso.stderr.transform(utf8.decoder).listen(log.write);
    unawaited(proceso.exitCode.then((codigo) {
      if (!listo.isCompleted) listo.completeError(StateError('El backend terminó ($codigo):\n$log'));
    }));
    await listo.future.timeout(const Duration(seconds: 40));
  }

  Future<void> detener() async {
    final proceso = _proceso;
    if (proceso == null) return;
    // En Windows, runInShell crea un cmd.exe: hay que cerrar el árbol completo.
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/PID', '${proceso.pid}', '/T', '/F']);
    } else {
      proceso.kill();
    }
    _proceso = null;
  }
}

/// Registra fuentes reales para las pruebas de pantalla. google_fonts nombra
/// cada peso como "Inter_regular", "Inter_500", "Inter_600" e "Inter_700".
Future<void> cargarFuentesDelSistema() async {
  const carpeta = r'C:\Windows\Fonts';
  const familias = {
    'Inter_regular': 'segoeui.ttf',
    'Inter_500': 'segoeui.ttf',
    'Inter_600': 'seguisb.ttf',
    'Inter_700': 'segoeuib.ttf',
    'Roboto': 'segoeui.ttf', // fuente por defecto de Material
  };
  for (final MapEntry(key: familia, value: archivo) in familias.entries) {
    final f = File('$carpeta${Platform.pathSeparator}$archivo');
    if (!f.existsSync()) continue; // fuera de Windows se usa la fuente de prueba
    final bytes = await f.readAsBytes();
    final loader = FontLoader(familia)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

/// Token en memoria: reemplaza a flutter_secure_storage durante las pruebas.
class TokenEnMemoria extends TokenStorage {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
