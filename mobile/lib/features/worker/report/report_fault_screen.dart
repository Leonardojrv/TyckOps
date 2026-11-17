import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/fault_category.dart';
import '../../../data/repositories/report_repository.dart';
import '../../auth/auth_session.dart';
import '../my_tickets_store.dart';
import '../worker_header.dart';
import '../worker_tokens.dart';

typedef _C = WorkerColors;
typedef _T = WorkerText;

/// T6 · Reportar una falla con foto (mockup colaborador/reportar_una_falla).
class ReportFaultScreen extends StatefulWidget {
  const ReportFaultScreen({
    super.key,
    required this.session,
    required this.store,
    required this.reports,
    this.picker,
  });

  final AuthSession session;
  final MyTicketsStore store;
  final ReportRepository reports;
  final ImagePicker? picker; // se puede reemplazar en pruebas

  @override
  State<ReportFaultScreen> createState() => _ReportFaultScreenState();
}

class _ReportFaultScreenState extends State<ReportFaultScreen> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  final _location = TextEditingController();
  final _description = TextEditingController();

  FaultCategory? _category;
  PickedPhoto? _photo;
  bool _sending = false;
  bool _submitted = false; // los errores se muestran después del primer intento
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {})); // contador 0 / 250
    _location.addListener(() {
      if (_submitted) setState(() {});
    });
    _recoverLostPhoto();
  }

  @override
  void dispose() {
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  // ---------- Validación (el servidor valida lo mismo) ----------

  String? get _categoryError => _category == null ? 'Elige el tipo de avería.' : null;

  String? get _locationError {
    final value = _location.text.trim();
    if (value.length < ReportLimits.minLocation) return 'Indica dónde está la falla.';
    if (value.length > ReportLimits.maxLocation) return 'La ubicación es muy larga.';
    return null;
  }

  String? get _descriptionError {
    final value = _description.text.trim();
    if (value.length < ReportLimits.minDescription) return 'Describe la falla con al menos 10 caracteres.';
    if (value.length > ReportLimits.maxDescription) return 'Máximo 250 caracteres.';
    return null;
  }

  // La foto es opcional: no entra en la validación.
  bool get _isValid => _categoryError == null && _locationError == null && _descriptionError == null;

  bool get _isDirty =>
      _category != null || _photo != null || _location.text.isNotEmpty || _description.text.isNotEmpty;

  // ---------- Foto ----------

  Future<void> _pickPhoto(ImageSource source) async {
    if (_sending) return;
    try {
      // Reducir antes de subir: menos datos móviles, y el teléfono vuelve a
      // codificar la imagen (máx. 1600 px, calidad 80) en vez del original.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
        requestFullMetadata: false, // no pedir GPS ni datos de la cámara
      );
      if (file == null) return; // el usuario canceló
      await _usePhoto(file);
    } on PlatformException catch (e) {
      final denied = e.code.contains('access_denied');
      _showMessage(denied
          ? 'Permite el acceso a la ${source == ImageSource.camera ? 'cámara' : 'galería'} en los ajustes del teléfono.'
          : 'No pudimos abrir la ${source == ImageSource.camera ? 'cámara' : 'galería'}.');
    }
  }

  Future<void> _usePhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    final photo = PickedPhoto(bytes: bytes, name: _displayName(file.name));
    if (photo.mimeType == null) return _showMessage('La foto debe ser JPG o PNG.');
    if (bytes.length > ReportLimits.maxPhotoBytes) return _showMessage('La foto supera los 5 MB.');
    if (mounted) setState(() => _photo = photo);
  }

  // Android puede cerrar la app mientras la cámara está abierta: al volver se
  // recupera la foto en vez de perderla.
  Future<void> _recoverLostPhoto() async {
    try {
      final lost = await _picker.retrieveLostData();
      if (!lost.isEmpty && lost.file != null) await _usePhoto(lost.file!);
    } on UnimplementedError {
      // Plataformas sin esta función (web, escritorio).
    }
  }

  /// Solo el nombre del archivo, corto y sin la ruta del teléfono.
  static String _displayName(String raw) {
    final name = raw.split(RegExp(r'[\\/]')).last;
    return name.length <= 18 ? name : '…${name.substring(name.length - 17)}';
  }

  // ---------- Envío ----------

  Future<void> _submit() async {
    if (_sending) return; // evita enviar dos veces
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_isValid) {
      _showMessage('Revisa los campos marcados.');
      return;
    }
    setState(() {
      _sending = true;
      _progress = 0;
    });
    HapticFeedback.lightImpact();
    try {
      final ticket = await widget.reports.create(
        category: _category!,
        location: _location.text.trim(),
        description: _description.text.trim(),
        photo: _photo, // opcional
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      _reset(); // el formulario queda limpio para el próximo reporte
      widget.store.load(); // el home y el contador se actualizan
      if (mounted) context.go(Routes.workerReportSent, extra: ticket);
    } on ApiException catch (e) {
      _showMessage(e.message);
    } on FormatException {
      _showMessage('El reporte se envió, pero no pudimos leer la respuesta. Revisa "Mis solicitudes".');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _reset() {
    _location.clear();
    _description.clear();
    setState(() {
      _category = null;
      _photo = null;
      _submitted = false;
      _progress = 0;
    });
  }

  Future<void> _cancel() async {
    if (_sending) return;
    if (_isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _C.white,
          title: Text('¿Descartar el reporte?', style: _T.headlineSm()),
          content: Text('Se borrarán los datos y la foto que ingresaste.', style: _T.bodyMd(_C.secondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Seguir editando', style: _T.labelLg(_C.secondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Descartar', style: _T.labelLg(_C.primaryContainer)),
            ),
          ],
        ),
      );
      if (discard != true) return;
      _reset();
    }
    if (mounted) context.go(Routes.workerHome);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- Pantalla ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: WorkerHeader(title: 'Reportar Falla', onSignOut: widget.session.signOut),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AbsorbPointer(
          absorbing: _sending,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const _SlaBanner(),
              const SizedBox(height: 16),
              const _Intro(),
              const SizedBox(height: 12),
              _Section(
                number: 1,
                title: 'Tipo de avería',
                required: true,
                trailing: _category == null
                    ? null
                    : Text(_category!.headline, style: _T.labelSm(_C.primaryContainer)),
                error: _submitted ? _categoryError : null,
                child: _CategoryGrid(
                  selected: _category,
                  onSelected: (c) {
                    HapticFeedback.selectionClick();
                    setState(() => _category = c);
                  },
                ),
              ),
              const SizedBox(height: 24),
              _Section(
                number: 2,
                title: 'Ubicación precisa',
                required: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.near_me, size: 14, color: _C.primaryContainer),
                    const SizedBox(width: 4),
                    Text('Edificio Central', style: _T.caption(_C.secondary)),
                  ],
                ),
                error: _submitted ? _locationError : null,
                child: _InputBox(
                  controller: _location,
                  hint: 'Ej: Piso 3, Sala de Capacitaciones A, junto a la ventana',
                  icon: Symbols.pin_drop,
                  maxLength: ReportLimits.maxLocation,
                  hasError: _submitted && _locationError != null,
                ),
              ),
              const SizedBox(height: 24),
              _Section(
                number: 3,
                title: 'Descripción detallada',
                required: true,
                trailing: Text(
                  '${_description.text.length} / ${ReportLimits.maxDescription}',
                  style: _T.caption(_C.secondary),
                ),
                error: _submitted ? _descriptionError : null,
                child: _InputBox(
                  controller: _description,
                  hint: 'Describe con claridad la falla observada, ruidos extraños o posibles riesgos para el personal...',
                  maxLength: ReportLimits.maxDescription,
                  lines: 4,
                  hasError: _submitted && _descriptionError != null,
                ),
              ),
              const SizedBox(height: 24),
              _Section(
                number: 4,
                title: 'Adjuntar fotografías',
                trailing: Text('Máximo 1 imagen', style: _T.caption(_C.secondary)),
                child: _PhotoPicker(
                  photo: _photo,
                  onCamera: () => _pickPhoto(ImageSource.camera),
                  onGallery: () => _pickPhoto(ImageSource.gallery),
                  onRemove: () => setState(() => _photo = null),
                ),
              ),
              const SizedBox(height: 24),
              const _EmergencyCallout(),
              const SizedBox(height: 20),
              _SubmitButton(sending: _sending, progress: _progress, onPressed: _submit),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _sending ? null : _cancel,
                  style: FilledButton.styleFrom(
                    backgroundColor: _C.containerHigh,
                    foregroundColor: _C.onSurface,
                    disabledBackgroundColor: _C.containerHigh,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancelar', style: _T.labelLg()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Encabezado del formulario =====================

class _SlaBanner extends StatelessWidget {
  const _SlaBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Symbols.info, size: 18, color: _C.primaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'SLA promedio actual: ',
                children: [
                  TextSpan(
                    text: '18 min de respuesta',
                    style: _T.labelSm(_C.onSurface).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              style: _T.labelSm(_C.secondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _C.primaryFixed, borderRadius: BorderRadius.circular(999)),
              child: Text(
                'RF-04 · INCIDENCIA',
                style: _T.caption(_C.onPrimaryFixed).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'ID Temporal #SG-${DateTime.now().year}-TMP',
                style: _T.caption(_C.secondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Nuevo reporte de falla o avería', style: _T.headlineMd().copyWith(height: 1.25)),
        const SizedBox(height: 4),
        Text(
          'Indica los detalles del problema para la asignación inmediata de un técnico en tu sede.',
          style: _T.bodySm(_C.secondary),
        ),
      ],
    );
  }
}

/// Título numerado de cada paso, con el error debajo si corresponde.
class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
    this.required = false,
    this.trailing,
    this.error,
  });

  final int number;
  final String title;
  final bool required;
  final Widget? trailing;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '$number. $title',
                  children: [
                    if (required) TextSpan(text: ' *', style: _T.labelLg(_C.primaryContainer)),
                  ],
                ),
                style: _T.labelLg(),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Symbols.error, size: 16, color: _C.error),
                      const SizedBox(width: 6),
                      Expanded(child: Text(error!, style: _T.bodySm(_C.error))),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ===================== 1. Tipo de avería =====================

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onSelected});

  final FaultCategory? selected;
  final ValueChanged<FaultCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = FaultCategory.values;
    return Semantics(
      label: 'Categoría del reporte',
      child: Column(
        children: [
          for (var row = 0; row < items.length; row += 2) ...[
            if (row > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = row; i < row + 2; i++) ...[
                    if (i > row) const SizedBox(width: 12),
                    Expanded(
                      child: _CategoryCard(
                        category: items[i],
                        selected: items[i] == selected,
                        onTap: () => onSelected(items[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.selected, required this.onTap});

  final FaultCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '${category.label}, ${category.examples}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _C.primaryContainer : Colors.transparent, width: 2),
            boxShadow: workerShadowSm,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selected ? _C.primaryFixed.withValues(alpha: 0.4) : _C.containerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        category.icon,
                        size: 26,
                        color: selected ? _C.primaryContainer : _C.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(category.label, style: _T.labelLg(), textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(category.examples, style: _T.caption(_C.secondary), textAlign: TextAlign.center),
                  ],
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle),
                    child: const Icon(Symbols.check, size: 14, color: _C.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== 2 y 3. Campos de texto =====================

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.hasError,
    this.icon,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final bool hasError;
  final IconData? icon;
  final int lines;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: color == Colors.transparent ? BorderSide.none : BorderSide(color: color, width: width),
        );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: workerShadowSm),
      child: TextField(
        controller: controller,
        minLines: lines,
        maxLines: lines,
        style: _T.bodyMd(),
        textCapitalization: TextCapitalization.sentences,
        textInputAction: lines > 1 ? TextInputAction.newline : TextInputAction.next,
        keyboardType: lines > 1 ? TextInputType.multiline : TextInputType.text,
        // El límite también lo valida el servidor.
        inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
        cursorColor: _C.primaryContainer,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _T.bodyMd(_C.secondary),
          hintMaxLines: lines,
          filled: true,
          fillColor: _C.white,
          isDense: true,
          contentPadding: icon == null
              ? const EdgeInsets.all(8)
              : const EdgeInsets.fromLTRB(0, 14, 12, 14),
          prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _C.secondary),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
          border: border(Colors.transparent, 0),
          enabledBorder: border(hasError ? _C.error : Colors.transparent, 1.5),
          focusedBorder: border(hasError ? _C.error : _C.primaryContainer, 2),
        ),
      ),
    );
  }
}

// ===================== 4. Foto =====================

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final PickedPhoto? photo;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SourceButton(
                icon: Symbols.photo_camera,
                iconColor: _C.primaryContainer,
                label: 'Tomar foto',
                onPressed: onCamera,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SourceButton(
                icon: Symbols.photo_library,
                iconColor: _C.secondary,
                label: 'Elegir de galería',
                onPressed: onGallery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (photo != null)
          _Thumbnail(photo: photo!, onRemove: onRemove)
        else
          _EmptySlot(onTap: onGallery),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.icon, required this.iconColor, required this.label, required this.onPressed});

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: workerShadowSm),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _C.white,
            foregroundColor: _C.onSurface,
            overlayColor: _C.containerHigh,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: _T.labelMd(), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photo, required this.onRemove});

  final PickedPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.containerHigh,
        borderRadius: BorderRadius.circular(8),
        boxShadow: workerShadowSm,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // cacheWidth: decodifica la miniatura pequeña (no 1600 px en memoria).
          Image.memory(photo.bytes, fit: BoxFit.cover, cacheWidth: 240, gaplessPlayback: true),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: _C.inverseSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                photo.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _T.caption(_C.white).copyWith(fontSize: 9, letterSpacing: 0),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              button: true,
              label: 'Eliminar foto',
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _C.inverseSurface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                  ),
                  child: const Icon(Symbols.close, size: 14, color: _C.inverseOnSurface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.white,
      borderRadius: BorderRadius.circular(8),
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(8), boxShadow: workerShadowSm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.add_a_photo, size: 24, color: _C.secondary),
              const SizedBox(height: 4),
              Text('1 cupo', style: _T.caption(_C.secondary).copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Emergencia y botones =====================

class _EmergencyCallout extends StatelessWidget {
  const _EmergencyCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.containerLow, borderRadius: BorderRadius.circular(12), boxShadow: workerShadowSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(color: _C.primaryContainer, shape: BoxShape.circle),
            child: const Icon(Symbols.emergency, size: 18, color: _C.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Riesgo inminente o fuga activa?', style: _T.labelMd()),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: 'Para emergencias que comprometan seguridad física, comunícate de inmediato al anexo ',
                    children: [
                      TextSpan(text: '*4400', style: _T.bodySm(_C.secondary).copyWith(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' de Central de Operaciones.'),
                    ],
                  ),
                  style: _T.bodySm(_C.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.sending, required this.progress, required this.onPressed});

  final bool sending;
  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -1),
          BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2), spreadRadius: -2),
        ],
      ),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: sending ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _C.primaryContainer,
            foregroundColor: _C.white,
            disabledBackgroundColor: _C.primaryContainer.withValues(alpha: 0.75),
            disabledForegroundColor: _C.white,
            overlayColor: _C.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: sending
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _C.white),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      progress > 0 && progress < 1 ? 'Enviando… ${(progress * 100).round()}%' : 'Enviando…',
                      style: _T.labelLg(_C.white),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.send, size: 20),
                    const SizedBox(width: 4),
                    Text('Enviar reporte', style: _T.labelLg(_C.white)),
                  ],
                ),
        ),
      ),
    );
  }
}
