import 'package:flutter/material.dart';
import '../../core/api/clinic_api.dart';
import '../auth/clinic_access.dart';
import 'clinical_file_save.dart';
import 'radiograph.dart';
import 'radiograph_repository.dart';

class ApiRadiographViewerScreen extends StatefulWidget {
  const ApiRadiographViewerScreen({
    super.key,
    required this.study,
    required this.repository,
  });
  final RadiographStudy study;
  final RadiographRepository repository;
  @override
  State<ApiRadiographViewerScreen> createState() =>
      _ApiRadiographViewerScreenState();
}

class _ApiRadiographViewerScreenState extends State<ApiRadiographViewerScreen> {
  Future<ApiFile>? _file;
  bool _saving = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ClinicAccessScope.of(context)?.can('radiografias', 'read') == true) {
      _file ??= widget.repository.getFile(widget.study);
    }
  }

  Future<void> _save(ApiFile file) async {
    setState(() => _saving = true);
    try {
      final saved = await saveClinicalFile(
        file.bytes,
        widget.study.fileName ?? 'radiografia',
        file.mimeType,
      );
      if (mounted && saved == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Archivo guardado. Puedes abrirlo desde la ubicación elegida.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el archivo.')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.study.patientName)),
    body: ClinicAccessScope.of(context)?.can('radiografias', 'read') != true
        ? const Center(
            child: Text('No tienes permiso para ver esta radiografía.'),
          )
        : FutureBuilder<ApiFile>(
            future: _file,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      OutlinedButton(
                        onPressed: () => setState(
                          () => _file = widget.repository.getFile(widget.study),
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final file = snapshot.data!;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(widget.study.fileName ?? 'Radiografía'),
                  ),
                  if (file.mimeType == 'application/pdf')
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Guarda el PDF para abrirlo con el visor de tu teléfono.',
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 8,
                        child: Center(
                          child: Image.memory(file.bytes, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _save(file),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(_saving ? 'Guardando...' : 'Guardar archivo'),
                    ),
                  ),
                ],
              );
            },
          ),
  );
}
