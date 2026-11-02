import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../auth/clinic_access.dart';
import 'local_png_files.dart' as png_files;

class LocalPngScreen extends StatefulWidget {
  const LocalPngScreen({super.key, this.patientName});
  final String? patientName;

  @override
  State<LocalPngScreen> createState() => _LocalPngScreenState();
}

class _LocalPngScreenState extends State<LocalPngScreen> {
  Uint8List? _bytes;
  String _name = 'radiografia.png';
  String? _message;
  bool _busy = false;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await png_files.pickPng();
      if (file == null || !mounted) return;
      final bytes = file['bytes'] as Uint8List;
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < 8 ||
          !List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v)) {
        throw const FormatException('Selecciona un archivo PNG valido.');
      }
      setState(() {
        _bytes = bytes;
        _name = (file['name'] as String? ?? 'radiografia.png')
            .split(RegExp(r'[/\\]'))
            .last;
        if (!_name.toLowerCase().endsWith('.png')) _name = 'radiografia.png';
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _message = error is FormatException
              ? error.message
              : 'No se pudo cargar el PNG. Intenta seleccionar el archivo nuevamente.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_bytes == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final saved = await png_files.savePng(_bytes!, _name);
      if (mounted && saved == true)
        setState(
          () => _message = kIsWeb
              ? 'Descarga iniciada. Revisa las descargas de tu navegador.'
              : 'Radiografia guardada correctamente.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _message =
              'No se pudo guardar. Elige una carpeta e intenta de nuevo.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permitted =
        ClinicAccessScope.of(context)?.can('radiografias', 'read') ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(widget.patientName ?? 'Radiografia PNG')),
      body: !permitted
          ? const Center(
              child: Text('No tienes permiso para visualizar radiografias.'),
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy ? null : _pick,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Cargar PNG'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy || _bytes == null ? null : _save,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Descargar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _bytes == null
                              ? 'Selecciona una radiografia PNG desde tu dispositivo.'
                              : _name,
                        ),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_message!),
                          ),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _bytes == null
                        ? const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                          )
                        : InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 8,
                            child: Center(
                              child: Image.memory(
                                _bytes!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) =>
                                    const Text(
                                      'No se pudo visualizar esta imagen PNG.',
                                    ),
                              ),
                            ),
                          ),
                  ),
                  if (_bytes != null)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        kIsWeb
                            ? 'Usa la rueda del mouse para ampliar y arrastra para mover la imagen.'
                            : 'Usa dos dedos para ampliar la imagen.',
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
