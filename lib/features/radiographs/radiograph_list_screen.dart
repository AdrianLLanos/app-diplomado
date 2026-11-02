import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_radiograph_viewer_screen.dart';
import 'radiograph_request_screen.dart';
import '../auth/clinic_access.dart';
import 'radiograph.dart';
import 'radiograph_repository.dart';
import 'radiograph_viewer_screen.dart';

class RadiographListScreen extends StatefulWidget {
  const RadiographListScreen({super.key, this.patientId, this.source});

  final String? patientId;
  final RadiographSource? source;

  @override
  State<RadiographListScreen> createState() => _RadiographListScreenState();
}

class _RadiographListScreenState extends State<RadiographListScreen> {
  late final RadiographSource _source = widget.source ?? RadiographRepository();
  ClinicAccess? _access;
  List<RadiographStudy> _studies = [];
  bool _loading = false;
  bool _hasNext = false;
  String? _error;
  int _page = 0;
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final access = ClinicAccessScope.of(context);
    if (identical(access, _access)) return;
    _access = access;
    _studies = [];
    _page = 0;
    _request++;
    if (access?.can('radiografias', 'read') == true) _load();
  }

  Future<void> _load({int? page}) async {
    if (!(_access?.can('radiografias', 'read') ?? false)) return;
    final request = ++_request;
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _source.getStudies(
        patientId: widget.patientId,
        page: targetPage,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page = targetPage;
        _hasNext = result.length > RadiographRepository.pageSize;
        _studies = result.take(RadiographRepository.pageSize).toList();
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error =
              'No se pudieron cargar las radiografias. Comprueba tu conexion y vuelve a intentar.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  bool _busy = false;

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RadiographRequestScreen(patientId: widget.patientId),
      ),
    );
    if (saved == true && mounted) await _load(page: 0);
  }

  Future<void> _action(RadiographStudy study, String action) async {
    final repo = _source;
    if (repo is! RadiographRepository || _busy) return;
    if (action != 'access') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'cancel' ? 'Cancelar solicitud' : 'Revocar enlace',
          ),
          content: Text(
            action == 'cancel'
                ? 'La solicitud quedara cancelada y el enlace dejara de funcionar.'
                : 'El enlace actual de CERPAX dejara de funcionar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (action == 'access') {
        final link = await repo.generateAccess(study.id);
        if (!mounted) return;
        final qr = link['qr'] as String?;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Acceso para CERPAX'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Comparte este enlace solo con CERPAX. Generarlo revoca cualquier enlace anterior.',
                  ),
                  if (qr != null)
                    Image.memory(
                      base64Decode(qr.split(',').last),
                      width: 220,
                      height: 220,
                    ),
                  SelectableText(link['url'] as String),
                  Text('Vence: ${link['vence_en']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: link['url'] as String),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Copiar enlace'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      } else {
        await repo.action(study.id, action);
        if (mounted) await _load();
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permitted =
        ClinicAccessScope.of(context)?.can('radiografias', 'read') ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radiografias'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(page: 0),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton:
          _source is RadiographRepository &&
              ClinicAccessScope.of(context)?.can('radiografias', 'create') ==
                  true
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text('Solicitar radiografia'),
            )
          : null,
      body: !permitted
          ? const Center(
              child: Text('No tienes permiso para consultar radiografias.'),
            )
          : RefreshIndicator(
              onRefresh: () => _load(page: 0),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  const Text(
                    'Consulta los estudios de tus pacientes. Desliza hacia abajo para actualizar.',
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null) ...[
                    Text(_error!),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ] else if (_studies.isEmpty)
                    const Text(
                      'No hay radiografias registradas para tus pacientes.',
                    )
                  else
                    ..._studies.map(
                      (study) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                study.patientName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(study.studyType),
                              const SizedBox(height: 8),
                              Text(study.status),
                              if (study.status == 'Pendiente' &&
                                  _source is RadiographRepository &&
                                  ClinicAccessScope.of(
                                        context,
                                      )?.can('radiografias', 'update') ==
                                      true)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _action(study, 'access'),
                                      child: const Text('Enlace / QR CERPAX'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _action(study, 'revoke'),
                                      child: const Text('Revocar enlace'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _action(study, 'cancel'),
                                      child: const Text('Cancelar solicitud'),
                                    ),
                                  ],
                                ),
                              if (study.hasFile) ...[
                                Text(
                                  study.fileName ?? 'Radiografia disponible',
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          _source is RadiographRepository
                                          ? ApiRadiographViewerScreen(
                                              study: study,
                                              repository: _source,
                                            )
                                          : RadiographViewerScreen(
                                              study: study,
                                              source: _source,
                                            ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Visualizar radiografia'),
                                ),
                              ] else
                                Text(
                                  study.status == 'Pendiente'
                                      ? 'Radiografia pendiente'
                                      : study.status == 'Cancelada'
                                      ? 'Solicitud cancelada'
                                      : 'Archivo no disponible',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!_loading && _error == null && (_page > 0 || _hasNext))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _page > 0
                              ? () => _load(page: _page - 1)
                              : null,
                          child: const Text('Anterior'),
                        ),
                        Text('Pagina ${_page + 1}'),
                        TextButton(
                          onPressed: _hasNext
                              ? () => _load(page: _page + 1)
                              : null,
                          child: const Text('Siguiente'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
