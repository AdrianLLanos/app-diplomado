import 'package:flutter/material.dart';
import '../doctors/doctor.dart';
import '../doctors/doctor_repository.dart';
import '../patients/patient.dart';
import '../patients/patient_repository.dart';
import 'appointment.dart';
import 'appointment_form_screen.dart';
import 'appointment_repository.dart';
import '../auth/clinic_access.dart';

class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({super.key, this.patientId, this.doctorId});
  final String? patientId;
  final String? doctorId;
  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  final _repo = AppointmentRepository();
  final _patientsRepo = PatientRepository();
  final _doctorsRepo = DoctorRepository();
  List<Appointment> _items = [];
  Map<String, Patient> _patients = {};
  Map<String, Doctor> _doctors = {};
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
      final items = await _repo.getAll();
      final patients = await _patientsRepo.getAll();
      final doctors = await _doctorsRepo.getAll();
      if (mounted)
        setState(() {
          _items = items;
          _patients = {for (final p in patients) p.id: p};
          _doctors = {for (final d in doctors) d.id: d};
        });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Appointment? item]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentFormScreen(
          appointment: item,
          patients: _patients.values.toList(),
          doctors: _doctors.values.toList(),
          patientId: widget.patientId,
          doctorId: widget.doctorId,
        ),
      ),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _delete(Appointment item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cita'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repo.delete(item.id);
        if (mounted) _load();
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ClinicAccessScope.of(context);
    final list = _items.where((item) {
      return (widget.patientId == null || item.patientId == widget.patientId) &&
          (widget.doctorId == null || item.doctorId == widget.doctorId);
    }).toList();
    final title = widget.patientId != null
        ? 'Citas del paciente'
        : widget.doctorId != null
        ? 'Citas del doctor'
        : 'Citas';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: access?.can('citas', 'create') == true
          ? FloatingActionButton.extended(
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('Nueva cita'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(child: Text(_error!))
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No hay citas registradas.')),
              )
            else
              ...list.map(
                (item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(
                      _patients[item.patientId]?.fullName ?? 'Paciente',
                    ),
                    subtitle: Text(
                      '${_doctors[item.doctorId]?.fullName ?? 'Doctor'} - ${_date(item.startsAt)} ${_time(item.startsAt)} - ${_status(item.status)}',
                    ),
                    onTap: access?.can('citas', 'update') == true
                        ? () => _edit(item)
                        : null,
                    trailing: access?.can('citas', 'delete') == true
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(item),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _status(String x) =>
      const {
        'scheduled': 'Programada',
        'confirmed': 'Confirmada',
        'completed': 'Atendida',
        'cancelled': 'Cancelada',
      }[x] ??
      x;
}
