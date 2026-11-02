import 'package:flutter/material.dart';

import 'patient.dart';
import 'patient_form_screen.dart';
import 'patient_repository.dart';
import '../auth/clinic_access.dart';
import '../radiographs/radiograph_list_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.patient});
  final Patient patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late Patient _patient;
  final _repository = PatientRepository();
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PatientFormScreen(patient: _patient),
      ),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar paciente'),
        content: Text(
          'Se eliminara el registro de ${_patient.fullName}. Esta accion no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _repository.delete(_patient.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el paciente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ficha del paciente'),
      actions: <Widget>[
        if (ClinicAccessScope.of(context)?.can('pacientes', 'update') == true)
          IconButton(
            tooltip: 'Editar paciente',
            onPressed: _deleting ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (ClinicAccessScope.of(context)?.can('pacientes', 'delete') == true)
          IconButton(
            tooltip: 'Eliminar paciente',
            onPressed: _deleting ? null : _delete,
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFFE0F2F1),
            child: Text(
              _patient.firstName.isEmpty
                  ? '?'
                  : _patient.firstName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 30, color: Color(0xFF006B72)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _patient.fullName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        if (ClinicAccessScope.of(context)?.can('radiografias', 'read') ==
            true) ...[
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RadiographListScreen(patientId: _patient.id),
              ),
            ),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Visualizar radiografias'),
          ),
          const SizedBox(height: 16),
        ],
        _section('Datos de contacto', <Widget>[
          _row(Icons.badge_outlined, 'Documento', _patient.documentNumber),
          _row(Icons.phone_outlined, 'Telefono', _patient.phone),
          _row(Icons.email_outlined, 'Correo', _patient.email),
          _row(Icons.home_outlined, 'Direccion', _patient.address),
          _row(
            Icons.cake_outlined,
            'Nacimiento',
            _patient.birthDate == null
                ? null
                : _formatDate(_patient.birthDate!),
          ),
        ]),
        const SizedBox(height: 16),
        _section('Notas medicas', <Widget>[
          Text(
            _patient.medicalNotes?.isNotEmpty == true
                ? _patient.medicalNotes!
                : 'Sin notas medicas registradas.',
          ),
        ]),
      ],
    ),
  );

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _row(IconData icon, String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: const Color(0xFF006B72)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label: ${value?.isNotEmpty == true ? value : 'No registrado'}',
          ),
        ),
      ],
    ),
  );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
