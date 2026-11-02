import '../../core/api/clinic_api.dart';
import 'appointment.dart';

class AppointmentRepository {
  AppointmentRepository({ClinicApi? client})
    : _client = client ?? ClinicApi.instance;
  final ClinicApi _client;

  Future<List<Appointment>> getAll() async {
    final rows = await _client.all('citas');
    return rows.map(Appointment.fromApi).toList();
  }

  Future<Appointment> getById(String id) async => Appointment.fromApi(
    Map<String, dynamic>.from(await _client.request('GET', 'citas/$id') as Map),
  );

  Future<List<Map<String, dynamic>>> slots(
    String doctorId,
    DateTime date, {
    String? excludeId,
  }) async {
    final day =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rows = await _client.request(
      'GET',
      'slots',
      query: {
        'medico': doctorId,
        'fecha': day,
        if (excludeId != null) 'exclude': excludeId,
      },
    );
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<void> save(Appointment appointment) =>
      _client.save('citas', appointment.id, appointment.toApi());
  Future<void> delete(String id) => _client.delete('citas', id);
}
