class DoctorSchedule {
  const DoctorSchedule({
    required this.id,
    required this.doctorId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.appointmentDuration,
    required this.slotType,
    required this.active,
  });

  final String id;
  final String doctorId;
  final String weekday;
  final String startTime;
  final String endTime;
  final int appointmentDuration;
  final String slotType;
  final bool active;

  static const _days = {
    'Monday': 'Lunes',
    'Tuesday': 'Martes',
    'Wednesday': 'Miercoles',
    'Thursday': 'Jueves',
    'Friday': 'Viernes',
    'Saturday': 'Sabado',
    'Sunday': 'Domingo',
  };
  factory DoctorSchedule.fromApi(Map<String, dynamic> row) => DoctorSchedule(
    id: row['id'].toString(),
    doctorId: row['usuario_id'].toString(),
    weekday: _days[row['dia_semana']] ?? row['dia_semana'].toString(),
    startTime: _shortTime(row['hora_inicio'].toString()),
    endTime: _shortTime(row['hora_fin'].toString()),
    appointmentDuration: (row['duracion_media_cita'] as num).toInt(),
    slotType: row['tipo_turno'] == 'Sequential' ? 'secuencial' : 'horario',
    active: row['estado'] == '1',
  );
  Map<String, dynamic> toApi() => {
    'usuario_id': doctorId,
    'dia_semana': _days.entries.firstWhere((day) => day.value == weekday).key,
    'hora_inicio': startTime,
    'hora_fin': endTime,
    'duracion_media_cita': appointmentDuration,
    'tipo_turno': slotType == 'secuencial' ? 'Sequential' : 'Timestamp',
    'estado': active ? '1' : '0',
  };

  factory DoctorSchedule.fromMap(Map<String, dynamic> map) => DoctorSchedule(
    id: map['id'] as String,
    doctorId: map['doctor_id'] as String,
    weekday: map['dia_semana'] as String,
    startTime: _shortTime(map['hora_inicio'] as String),
    endTime: _shortTime(map['hora_fin'] as String),
    appointmentDuration: map['duracion_cita'] as int,
    slotType: map['tipo_turno'] as String,
    active: map['activo'] as bool,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'doctor_id': doctorId,
    'dia_semana': weekday,
    'hora_inicio': startTime,
    'hora_fin': endTime,
    'duracion_cita': appointmentDuration,
    'tipo_turno': slotType,
    'activo': active,
  };

  int get startMinutes => _minutes(startTime);
  int get endMinutes => _minutes(endTime);

  static int _minutes(String value) {
    final values = value.split(':');
    return int.parse(values[0]) * 60 + int.parse(values[1]);
  }

  static String _shortTime(String value) => value.substring(0, 5);
}
