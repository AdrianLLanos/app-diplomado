import '../../core/api/clinic_api.dart';
import 'radiograph.dart';

abstract class RadiographSource {
  Future<List<RadiographStudy>> getStudies({String? patientId, int page = 0});
  Future<String> createViewingUrl(RadiographStudy study);
}

class RadiographRepository implements RadiographSource {
  RadiographRepository({ClinicApi? client})
    : _client = client ?? ClinicApi.instance;
  final ClinicApi _client;
  static const pageSize = 25;

  @override
  Future<List<RadiographStudy>> getStudies({
    String? patientId,
    int page = 0,
  }) async {
    final query = {
      'page': '$page',
      if (patientId != null) 'paciente': patientId,
    };
    final data = await _client.request('GET', 'radiographs', query: query);
    final rows = (data['rows'] as List)
        .map(
          (r) => RadiographStudy.fromApi(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
    // Existing list uses an extra item to signal that the next page exists.
    if ((page + 1) * pageSize < (data['total'] as num) && rows.isNotEmpty)
      rows.add(rows.last);
    return rows;
  }

  Future<ApiFile> getFile(RadiographStudy study) {
    if (!study.hasFile)
      throw StateError('La radiografia aun no tiene archivo.');
    return _client.file('radiographs/${study.id}/file');
  }

  @override
  Future<String> createViewingUrl(RadiographStudy study) async {
    final file = await getFile(study);
    return Uri.dataFromBytes(file.bytes, mimeType: file.mimeType).toString();
  }

  Future<void> create({
    required String patientId,
    required String type,
    String notes = '',
    String? doctorId,
  }) async {
    await _client.request(
      'POST',
      'radiographs',
      body: {
        'paciente_id': patientId,
        'tipo': type,
        'indicaciones': notes,
        if (doctorId != null) 'odontologo_id': doctorId,
      },
    );
  }

  Future<Map<String, dynamic>> generateAccess(String id) async =>
      Map<String, dynamic>.from(
        await _client.request(
              'POST',
              'radiographs/$id/access',
              body: {'horas': 24},
            )
            as Map,
      );
  Future<void> action(String id, String action) async {
    if (!['revoke', 'cancel'].contains(action))
      throw ArgumentError.value(action);
    await _client.request('POST', 'radiographs/$id/$action', body: {});
  }
}
