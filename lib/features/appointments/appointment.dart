class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.startsAt,
    required this.endsAt,
    required this.reason,
    required this.status,
  });
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;
  final String status;

  factory Appointment.fromApi(Map<String, dynamic> row) {
    final date = row['fecha_cita'].toString().substring(0, 10);
    return Appointment(
      id: row['id'].toString(),
      patientId: row['usuario_id'].toString(),
      doctorId: row['medico_id'].toString(),
      startsAt: DateTime.parse('${date}T${row['hora_inicio']}'),
      endsAt: DateTime.parse('${date}T${row['hora_fin']}'),
      reason: row['motivo_consulta'] as String? ?? '',
      status: 'scheduled',
    );
  }

  Map<String, dynamic> toApi() => {
    'usuario_id': patientId,
    'medico_id': doctorId,
    'fecha_cita':
        '${startsAt.year.toString().padLeft(4, '0')}-${startsAt.month.toString().padLeft(2, '0')}-${startsAt.day.toString().padLeft(2, '0')}',
    'hora_inicio': _time(startsAt),
    'hora_fin': _time(endsAt),
    'motivo_consulta': reason.trim(),
  };
  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  factory Appointment.fromMap(Map<String, dynamic> data) => Appointment(
    id: data['id'] as String,
    patientId: data['paciente_id'] as String,
    doctorId: data['doctor_id'] as String,
    startsAt: DateTime.parse(data['inicia_en'] as String).toLocal(),
    endsAt: data['finaliza_en'] == null
        ? DateTime.parse(
            data['inicia_en'] as String,
          ).toLocal().add(const Duration(minutes: 30))
        : DateTime.parse(data['finaliza_en'] as String).toLocal(),
    reason: data['motivo'] as String? ?? '',
    status: data['estado'] as String,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'paciente_id': patientId,
    'doctor_id': doctorId,
    'inicia_en': startsAt.toUtc().toIso8601String(),
    'finaliza_en': endsAt.toUtc().toIso8601String(),
    'motivo': reason.trim().isEmpty ? null : reason.trim(),
    'estado': status,
  };
}
