import 'package:flutter/material.dart';

import 'doctor.dart';
import '../auth/clinic_access.dart';
import 'doctor_form_screen.dart';
import 'doctor_repository.dart';
import 'doctor_schedule_list_screen.dart';

class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({super.key, required this.doctor});
  final Doctor doctor;
  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  final _repository = DoctorRepository();
  bool _deleting = false;

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DoctorFormScreen(doctor: widget.doctor),
      ),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _schedules() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorScheduleListScreen(doctor: widget.doctor),
      ),
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar doctor'),
        content: Text(
          'Se eliminara a ${widget.doctor.fullName}. El servidor verificara si tiene registros relacionados.',
        ),
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
    setState(() => _deleting = true);
    try {
      await _repository.delete(widget.doctor.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el doctor.')),
        );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ficha del doctor'),
      actions: <Widget>[
        if (ClinicAccessScope.of(context)?.can('doctores', 'update') == true)
          IconButton(
            tooltip: 'Editar doctor',
            onPressed: _deleting ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (ClinicAccessScope.of(context)?.can('doctores', 'delete') == true)
          IconButton(
            tooltip: 'Eliminar doctor',
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Center(
          child: CircleAvatar(
            radius: 38,
            backgroundColor: const Color(0xFFE0F2F1),
            child: Icon(
              Icons.medical_services_outlined,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.doctor.fullName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (widget.doctor.specialty?.isNotEmpty == true)
          Text(widget.doctor.specialty!, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Contacto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _row(Icons.phone_outlined, 'Telefono', widget.doctor.phone),
                _row(Icons.email_outlined, 'Correo', widget.doctor.email),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (ClinicAccessScope.of(context)?.can('horarios', 'read') == true)
          FilledButton.icon(
            onPressed: _schedules,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Gestionar horarios'),
          ),
      ],
    ),
  );
  Widget _row(IconData icon, String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
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
}
