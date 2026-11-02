import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/clinic_access.dart';
import 'radiograph.dart';
import 'radiograph_repository.dart';

class RadiographViewerScreen extends StatefulWidget {
  const RadiographViewerScreen({
    super.key,
    required this.study,
    required this.source,
  });

  final RadiographStudy study;
  final RadiographSource source;

  @override
  State<RadiographViewerScreen> createState() => _RadiographViewerScreenState();
}

class _RadiographViewerScreenState extends State<RadiographViewerScreen> {
  Future<String>? _url;
  ClinicAccess? _access;
  String? _pdfError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final access = ClinicAccessScope.of(context);
    if (identical(access, _access)) return;
    _access = access;
    _url = access?.can('radiografias', 'read') == true && widget.study.hasFile
        ? widget.source.createViewingUrl(widget.study)
        : null;
  }

  void _retry() => setState(() {
    _pdfError = null;
    _url = widget.source.createViewingUrl(widget.study);
  });

  Future<void> _openPdf(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('No hay un visor disponible.');
      if (mounted) setState(() => _pdfError = null);
    } catch (_) {
      if (mounted)
        setState(
          () => _pdfError =
              'No se pudo abrir el PDF. Comprueba que el telefono tenga un navegador o visor PDF.',
        );
    }
  }

  Widget _failure() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No se pudo abrir la radiografia. El archivo puede no estar disponible o tu acceso puede haber cambiado.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _retry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final permitted =
        ClinicAccessScope.of(context)?.can('radiografias', 'read') ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(widget.study.patientName)),
      body: !permitted
          ? const Center(
              child: Text('No tienes permiso para ver esta radiografia.'),
            )
          : !widget.study.hasFile
          ? const Center(child: Text('Radiografia pendiente'))
          : FutureBuilder<String>(
              future: _url,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _failure();
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (widget.study.isPdf) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.study.fileName ?? 'Radiografia PDF'),
                          const SizedBox(height: 12),
                          const Text(
                            'El PDF se abrira con el visor o navegador del telefono.',
                          ),
                          FilledButton.icon(
                            onPressed: () => _openPdf(snapshot.data!),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Abrir PDF'),
                          ),
                          if (_pdfError != null) Text(_pdfError!),
                          TextButton(
                            onPressed: _retry,
                            child: const Text('Renovar acceso'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Usa dos dedos para ampliar y arrastra para mover la imagen.',
                      ),
                    ),
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 8,
                        child: Center(
                          child: Image.network(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (context, error, stack) => _failure(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
