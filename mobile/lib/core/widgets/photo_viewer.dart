// ¿PARA QUÉ SIRVE?
//   Muestra la foto de un ticket en grande, a pantalla completa.
//
// ¿QUÉ HACE?
//   Abre la foto con fondo negro, permite acercar con dos dedos o doble toque y se
//   cierra con la X. La foto se pide con tu sesión y queda solo en memoria.
//
// ¿CÓMO LO CAMBIO?
//   La usan el colaborador (T7) y el administrador (T13). Si cambias el zoom máximo
//   o los controles, se cambia para los dos.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../network/api_exception.dart';

/// Abre la foto de un ticket a pantalla completa, con zoom de dos dedos.
///
/// Sirve para el colaborador (T7) y para el administrador (T13): lo único que
/// cambia es de dónde sale la foto, por eso se recibe [loadPhoto]. Si quieres
/// cambiar el fondo, los botones o el zoom máximo, se hace aquí y se aplica en
/// las dos apps a la vez.
///
/// Seguridad: la foto se pide con la sesión del usuario y vive solo en memoria
/// (no se guarda en la galería ni en el disco), porque puede mostrar áreas
/// internas de la empresa.
Future<void> showPhotoViewer(
  BuildContext context, {
  required Future<Uint8List> Function() loadPhoto,
  String? title,
  Object? heroTag,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _PhotoViewerPage(loadPhoto: loadPhoto, title: title, heroTag: heroTag),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoViewerPage extends StatefulWidget {
  const _PhotoViewerPage({required this.loadPhoto, this.title, this.heroTag});

  final Future<Uint8List> Function() loadPhoto;
  final String? title;
  final Object? heroTag;

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late Future<Uint8List> _photo = widget.loadPhoto();
  final _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  // Doble toque: acerca al doble, o vuelve al tamaño normal si ya estaba acercada.
  void _toggleZoom(TapDownDetails details) {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed) {
      _zoom.value = Matrix4.identity();
    } else {
      final p = details.localPosition;
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-p.dx, -p.dy, 0, 1)
        ..scaleByDouble(2, 2, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Barras del sistema claras sobre el fondo negro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<Uint8List>(
                future: _photo,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final message = snapshot.error is ApiException
                        ? (snapshot.error! as ApiException).message
                        : 'No pudimos cargar la foto.';
                    return _ErrorView(
                      message: message,
                      onRetry: () => setState(() => _photo = widget.loadPhoto()),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                  }
                  final image = Image.memory(snapshot.data!, fit: BoxFit.contain, gaplessPlayback: true);
                  return GestureDetector(
                    onDoubleTapDown: _toggleZoom,
                    onDoubleTap: () {},
                    child: InteractiveViewer(
                      transformationController: _zoom,
                      minScale: 1,
                      maxScale: 5, // hasta 5x para ver detalles, como un enchufe quemado
                      child: Center(
                        child: widget.heroTag == null ? image : Hero(tag: widget.heroTag!, child: image),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Barra superior: título y botón para cerrar.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title ?? 'Fotografía',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Symbols.close, color: Colors.white, size: 26),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Pista de uso abajo.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Pellizca o toca dos veces para acercar',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.broken_image, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
