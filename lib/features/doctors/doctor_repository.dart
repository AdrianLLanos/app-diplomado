import '../../core/api/clinic_api.dart';
import 'doctor.dart';

class DoctorRepository {
  DoctorRepository({ClinicApi? client})
    : _client = client ?? ClinicApi.instance;
  final ClinicApi _client;

  Future<List<Doctor>> getAll() async {
    final rows = await _client.all('odontologos');
    return rows.map(Doctor.fromApi).toList();
  }

  Future<Doctor> getById(String id) async => Doctor.fromApi(
    Map<String, dynamic>.from(
      await _client.request('GET', 'odontologos/$id') as Map,
    ),
  );

  Future<void> save(Doctor doctor) =>
      _client.save('odontologos', doctor.id, doctor.toApi());
  Future<void> delete(String id) => _client.delete('odontologos', id);
}
