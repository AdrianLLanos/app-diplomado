import 'package:flutter/material.dart';
import '../auth/clinic_access.dart';
import '../patients/patient.dart';
import '../patients/patient_repository.dart';
import '../doctors/doctor.dart';
import '../doctors/doctor_repository.dart';
import 'radiograph_repository.dart';

class RadiographRequestScreen extends StatefulWidget {
  const RadiographRequestScreen({super.key, this.patientId});
  final String? patientId;
  @override
  State<RadiographRequestScreen> createState() =>
      _RadiographRequestScreenState();
}

class _RadiographRequestScreenState extends State<RadiographRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _type = TextEditingController();
  final _notes = TextEditingController();
  List<Patient> _patients = [];
  List<Doctor> _doctors = [];
  String? _patientId;
  String? _doctorId;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patients = await PatientRepository().getAll();
      if (!mounted) return;
      final doctors = ClinicAccessScope.of(context)?.isAdministrator == true
          ? await DoctorRepository().getAll()
          : <Doctor>[];
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _doctors = doctors;
        _patientId = patients.any((p) => p.id == widget.patientId)
            ? widget.patientId
            : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await RadiographRepository().create(
        patientId: _patientId!,
        type: _type.text.trim(),
        notes: _notes.text.trim(),
        doctorId: _doctorId,
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
    _type.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ClinicAccessScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar radiografía')),
      body: access?.can('radiografias', 'create') != true
          ? const Center(
              child: Text('No tienes permiso para crear solicitudes.'),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'El paciente debe estar asignado al odontólogo en el sistema web. CERPAX recibirá el estudio mediante el enlace que generes después de guardar.',
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: _saving ? null : _load,
                      child: const Text('Recargar pacientes'),
                    ),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _patientId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Paciente'),
                    items: _patients
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.fullName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _patientId = value),
                    validator: (v) =>
                        v == null ? 'Selecciona un paciente' : null,
                  ),
                  if (access?.isAdministrator == true) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _doctorId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Odontólogo responsable',
                      ),
                      items: _doctors
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                d.fullName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _doctorId = value),
                      validator: (v) =>
                          v == null ? 'Selecciona un odontólogo' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _type,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de estudio',
                      hintText: 'Panorámica, periapical…',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Escribe el tipo de estudio'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notes,
                    maxLength: 2000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Indicaciones',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Crear solicitud'),
                  ),
                ],
              ),
            ),
    );
  }
}
