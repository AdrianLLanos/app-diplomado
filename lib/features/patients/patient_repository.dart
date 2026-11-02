import '../../core/api/clinic_api.dart';
import 'patient.dart';

class PatientRepository {
  PatientRepository({ClinicApi? client})
    : _client = client ?? ClinicApi.instance;
  final ClinicApi _client;

  Future<List<Patient>> getAll() async {
    final rows = await _client.all('pacientes');
    return rows.map(Patient.fromApi).toList();
  }

  Future<Patient> getById(String id) async => Patient.fromApi(
    Map<String, dynamic>.from(
      await _client.request('GET', 'pacientes/$id') as Map,
    ),
  );

  Future<void> save(Patient patient) =>
      _client.save('pacientes', patient.id, patient.toApi());
  Future<void> delete(String id) => _client.delete('pacientes', id);
}
