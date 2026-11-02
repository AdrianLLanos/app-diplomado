import 'package:flutter/material.dart';

import 'doctor.dart';
import 'doctor_schedule.dart';
import 'doctor_schedule_repository.dart';

class DoctorScheduleFormScreen extends StatefulWidget {
  const DoctorScheduleFormScreen({
    super.key,
    required this.doctor,
    this.schedule,
  });
  final Doctor doctor;
  final DoctorSchedule? schedule;

  @override
  State<DoctorScheduleFormScreen> createState() =>
      _DoctorScheduleFormScreenState();
}

class _DoctorScheduleFormScreenState extends State<DoctorScheduleFormScreen> {
  static const _weekdays = <String>[
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo',
  ];
  final _formKey = GlobalKey<FormState>();
  final _repository = DoctorScheduleRepository();
  late String _weekday;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _duration;
  late String _slotType;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _weekday = schedule?.weekday ?? 'Lunes';
    _startTime = _toTime(schedule?.startTime ?? '08:00');
    _endTime = _toTime(schedule?.endTime ?? '12:00');
    _duration = schedule?.appointmentDuration ?? 30;
    _slotType = schedule?.slotType ?? 'horario';
    _active = schedule?.active ?? true;
  }

  Future<void> _pickTime(bool isStart) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (selected != null)
      setState(() {
        if (isStart) {
          _startTime = selected;
        } else {
          _endTime = selected;
        }
      });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final schedule = DoctorSchedule(
      id: widget.schedule?.id ?? '',
      doctorId: widget.doctor.id,
      weekday: _weekday,
      startTime: _toString(_startTime),
      endTime: _toString(_endTime),
      appointmentDuration: _duration,
      slotType: _slotType,
      active: _active,
    );
    if (schedule.endMinutes <= schedule.startMinutes) {
      _message('La hora final debe ser posterior a la hora inicial.');
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = await _repository.getByDoctor(widget.doctor.id);
      final overlap = existing.any(
        (item) =>
            item.id != schedule.id &&
            item.weekday == schedule.weekday &&
            item.startMinutes < schedule.endMinutes &&
            item.endMinutes > schedule.startMinutes,
      );
      if (overlap) {
        _message('Este horario se superpone con otro turno del doctor.');
        return;
      }
      await _repository.save(schedule);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.schedule == null ? 'Nuevo horario' : 'Editar horario'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            widget.doctor.fullName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _weekday,
            decoration: const InputDecoration(labelText: 'Dia de atencion'),
            items: _weekdays
                .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                .toList(),
            onChanged: (value) => setState(() => _weekday = value!),
          ),
          const SizedBox(height: 12),
          _timeButton('Hora de inicio', _startTime, () => _pickTime(true)),
          const SizedBox(height: 12),
          _timeButton('Hora de finalizacion', _endTime, () => _pickTime(false)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _duration,
            decoration: const InputDecoration(
              labelText: 'Duracion de consulta',
            ),
            items:
                (<int>{5, 10, 15, 20, 30, 45, 60, _duration}.toList()..sort())
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes minutos'),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _duration = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _slotType,
            decoration: const InputDecoration(labelText: 'Tipo de turno'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'horario', child: Text('Por horario')),
              DropdownMenuItem(value: 'secuencial', child: Text('Correlativo')),
            ],
            onChanged: (value) => setState(() => _slotType = value!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Horario activo'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando...' : 'Guardar horario'),
          ),
        ],
      ),
    ),
  );

  Widget _timeButton(String label, TimeOfDay value, VoidCallback onPressed) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.schedule_outlined),
        label: Text('$label: ${_formatTime(value)}'),
      );

  TimeOfDay _toTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _toString(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  String _formatTime(TimeOfDay value) => _toString(value);
}
