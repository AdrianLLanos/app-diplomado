import 'package:flutter/material.dart';
import '../../core/api/clinic_api.dart';
import '../auth/clinic_access.dart';

/// Read-only access to modules whose full editors remain in the web system.
class ApiRecordsScreen extends StatefulWidget {
  const ApiRecordsScreen({
    super.key,
    required this.resource,
    required this.title,
  });
  final String resource;
  final String title;
  @override
  State<ApiRecordsScreen> createState() => _ApiRecordsScreenState();
}

class _ApiRecordsScreenState extends State<ApiRecordsScreen> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _labels = {};
  Map<String, String> _permissions = {};
  String? _error;
  bool _loading = false;
  int _page = 0;
  int _total = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  bool get _allowed =>
      ClinicAccessScope.of(context)?.can(widget.resource, 'read') == true;

  Future<void> _load() async {
    if (!_allowed) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ClinicApi.instance;
      List<Map<String, dynamic>> rows;
      var total = 0;
      if (widget.resource == 'roles') {
        final data = await api.request('GET', 'roles');
        rows = (data['roles'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _permissions = {
          for (final p in data['permissions'] as List)
            p['id'].toString(): p['nombre'] as String,
        };
        total = rows.length;
        _labels = {'nombre': 'Nombre', 'permisos': 'Permisos'};
      } else {
        final catalog = await api.request('GET', 'catalog') as List;
        final key = widget.resource == 'usuarios'
            ? 'usuarios'
            : widget.resource;
        final module = catalog.cast<Map>().firstWhere((m) => m['key'] == key);
        _labels = {
          for (final f in module['fields'] as List)
            if (f['secret'] != true) f['name'] as String: f['label'] as String,
        };
        final data = await api.request(
          'GET',
          widget.resource == 'usuarios' ? 'cuentas' : widget.resource,
          query: {'page': '$_page', 'size': '25'},
        );
        rows = (data['rows'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        total = (data['total'] as num).toInt();
      }
      if (mounted)
        setState(() {
          _rows = rows;
          _total = total;
        });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _value(String key, dynamic value) {
    if (key == 'permisos' && value is List)
      return value
          .map((id) => _permissions[id.toString()] ?? '')
          .where((p) => p.isNotEmpty)
          .join(', ');
    if (value is List) return value.map((v) => _value('', v)).join('\n');
    if (value is Map)
      return value.entries
          .map(
            (e) =>
                '${e.key.toString().replaceAll('_', ' ')}: ${_value('', e.value)}',
          )
          .join(' · ');
    return value?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: !_allowed
        ? const Center(
            child: Text('No tienes permiso para consultar esta sección.'),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Consulta los registros compartidos con el sistema web. La edición de esta sección se realiza desde la web.',
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null) ...[
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ] else if (_rows.isEmpty)
                  const Text('No hay registros.')
                else
                  ..._rows.map(
                    (row) => Card(
                      child: ExpansionTile(
                        title: Text(
                          row['nombre']?.toString() ??
                              row['fecha']?.toString().split('T').first ??
                              'Registro ${row['id']}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final entry in row.entries)
                                  if (_labels.containsKey(entry.key) &&
                                      entry.value != null &&
                                      entry.value.toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: SelectableText(
                                        '${_labels[entry.key]}: ${_value(entry.key, entry.value)}',
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.resource != 'roles' && !_loading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _page == 0
                            ? null
                            : () {
                                _page--;
                                _load();
                              },
                        child: const Text('Anterior'),
                      ),
                      Text('Página ${_page + 1}'),
                      TextButton(
                        onPressed: (_page + 1) * 25 >= _total
                            ? null
                            : () {
                                _page++;
                                _load();
                              },
                        child: const Text('Siguiente'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
  );
}
