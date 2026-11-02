import '../../core/api/clinic_api.dart';
import 'doctor_schedule.dart';

class DoctorScheduleRepository {
  DoctorScheduleRepository({ClinicApi? client})
    : _client = client ?? ClinicApi.instance;
  final ClinicApi _client;

  Future<List<DoctorSchedule>> getByDoctor(String doctorId) async {
    final rows = await _client.all('horarios');
    return rows
        .where((row) => row['usuario_id'].toString() == doctorId)
        .map(DoctorSchedule.fromApi)
        .toList();
  }

  Future<void> save(DoctorSchedule schedule) =>
      _client.save('horarios', schedule.id, schedule.toApi());
  Future<void> delete(String id) => _client.delete('horarios', id);
}
