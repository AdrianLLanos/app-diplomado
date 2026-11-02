import 'package:flutter/material.dart';

import 'doctor.dart';
import '../auth/clinic_access.dart';
import 'doctor_schedule.dart';
import 'doctor_schedule_form_screen.dart';
import 'doctor_schedule_repository.dart';

class DoctorScheduleListScreen extends StatefulWidget {
  const DoctorScheduleListScreen({super.key, required this.doctor});
  final Doctor doctor;

  @override
  State<DoctorScheduleListScreen> createState() =>
      _DoctorScheduleListScreenState();
}

class _DoctorScheduleListScreenState extends State<DoctorScheduleListScreen> {
  final _repository = DoctorScheduleRepository();
  List<DoctorSchedule> _schedules = <DoctorSchedule>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schedules = await _repository.getByDoctor(widget.doctor.id);
      if (mounted) setState(() => _schedules = schedules);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([DoctorSchedule? schedule]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            DoctorScheduleFormScreen(doctor: widget.doctor, schedule: schedule),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(DoctorSchedule schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar horario'),
        content: Text('Eliminar el horario de ${schedule.weekday}?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repository.delete(schedule.id);
      _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el horario.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Horarios: ${widget.doctor.fullName}')),
    floatingActionButton:
        ClinicAccessScope.of(context)?.can('horarios', 'create') == true
        ? FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo horario'),
          )
        : null,
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text('Horarios de atencion'),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Center(
              child: Column(
                children: <Widget>[
                  Text(_error!, textAlign: TextAlign.center),
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else if (_schedules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No hay horarios registrados.')),
            )
          else
            ..._schedules.map(
              (schedule) => Card(
                child: ListTile(
                  leading: Icon(
                    schedule.active
                        ? Icons.event_available_outlined
                        : Icons.event_busy_outlined,
                  ),
                  title: Text(
                    '${schedule.weekday}: ${schedule.startTime} - ${schedule.endTime}',
                  ),
                  subtitle: Text(
                    '${schedule.appointmentDuration} min · ${schedule.slotType == 'horario' ? 'Por horario' : 'Correlativo'} · ${schedule.active ? 'Activo' : 'Inactivo'}',
                  ),
                  onTap:
                      ClinicAccessScope.of(
                            context,
                          )?.can('horarios', 'update') ==
                          true
                      ? () => _openForm(schedule)
                      : null,
                  trailing:
                      ClinicAccessScope.of(
                            context,
                          )?.can('horarios', 'delete') ==
                          true
                      ? IconButton(
                          tooltip: 'Eliminar horario',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(schedule),
                        )
                      : null,
                ),
              ),
            ),
          const SizedBox(height: 84),
        ],
      ),
    ),
  );
}
