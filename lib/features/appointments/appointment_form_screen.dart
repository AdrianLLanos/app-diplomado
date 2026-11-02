import 'package:flutter/material.dart';
import '../../core/api/clinic_api.dart';
import '../patients/patient.dart';
import '../doctors/doctor.dart';
import '../auth/clinic_access.dart';
import 'appointment.dart';
import 'appointment_repository.dart';

class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({
    super.key,
    this.appointment,
    required this.patients,
    required this.doctors,
    this.patientId,
    this.doctorId,
  });
  final Appointment? appointment;
  final List<Patient> patients;
  final List<Doctor> doctors;
  final String? patientId;
  final String? doctorId;
  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _form = GlobalKey<FormState>();
  final _repo = AppointmentRepository();
  late final TextEditingController _reason;
  late DateTime _date;
  String? _patient;
  String? _doctor;
  String? _slot;
  String? _error;
  List<Map<String, dynamic>> _slots = [];
  bool _loading = false;
  bool _saving = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final item = widget.appointment;
    _reason = TextEditingController(text: item?.reason ?? '');
    _date = item?.startsAt ?? DateTime.now();
    _patient = item?.patientId ?? widget.patientId;
    _doctor = item?.doctorId ?? widget.doctorId;
    if (ClinicAccessSession.current.value?.isDentist == true)
      _doctor ??= ClinicApi.instance.userId;
    _loadSlots(select: item == null ? null : _time(item.startsAt));
  }

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  DateTime _at(String time) {
    final parts = time.split(':');
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Future<void> _loadSlots({String? select}) async {
    final request = ++_request;
    setState(() {
      _slots = [];
      _slot = null;
      _error = null;
      _loading = _doctor != null;
    });
    if (_doctor == null) return;
    try {
      final slots = await _repo.slots(
        _doctor!,
        _date,
        excludeId: widget.appointment?.id,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _slots = slots;
        _slot = slots.any((s) => s['inicio'] == select) ? select : null;
      });
    } catch (error) {
      if (mounted && request == _request)
        setState(() => _error = error.toString());
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _slot == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final slot = _slots.firstWhere((s) => s['inicio'] == _slot);
      await _repo.save(
        Appointment(
          id: widget.appointment?.id ?? '',
          patientId: _patient!,
          doctorId: _doctor!,
          startsAt: _at(slot['inicio'] as String),
          endsAt: _at(slot['fin'] as String),
          reason: _reason.text,
          status: 'scheduled',
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _request++;
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.appointment == null ? 'Nueva cita' : 'Editar cita'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          DropdownButtonFormField<String>(
            initialValue: _patient,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Paciente'),
            items: widget.patients
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.fullName, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _saving ? null : (v) => setState(() => _patient = v),
            validator: (v) => v == null ? 'Selecciona un paciente' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _doctor,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Odontólogo'),
            items: widget.doctors
                .map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(d.fullName, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) {
                    _doctor = v;
                    _loadSlots();
                  },
            validator: (v) => v == null ? 'Selecciona un odontólogo' : null,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () async {
                    final now = DateTime.now();
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: _date.isBefore(now) ? _date : now,
                      lastDate: DateTime(now.year + 3),
                    );
                    if (selected != null && mounted) {
                      _date = selected;
                      _loadSlots();
                    }
                  },
            child: Text('Fecha: ${_date.day}/${_date.month}/${_date.year}'),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<String>(
              key: ValueKey('$_doctor-$_date-$_request'),
              initialValue: _slot,
              decoration: const InputDecoration(
                labelText: 'Horario disponible',
              ),
              items: _slots
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['inicio'] as String,
                      child: Text('${s['inicio']} – ${s['fin']}'),
                    ),
                  )
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _slot = v),
              validator: (v) =>
                  v == null ? 'Selecciona un horario disponible' : null,
            ),
          if (!_loading && _doctor != null && _slots.isEmpty)
            const Text(
              'No hay horarios disponibles para esta fecha. Revisa los horarios del odontólogo o elige otro día.',
            ),
          TextButton(
            onPressed: _loading || _saving ? null : _loadSlots,
            child: const Text('Actualizar disponibilidad'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reason,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Motivo de consulta'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving || _loading || _slot == null ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar cita'),
          ),
        ],
      ),
    ),
  );
}
