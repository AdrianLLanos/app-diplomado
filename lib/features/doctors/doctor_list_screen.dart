import 'package:flutter/material.dart';

import 'doctor.dart';
import '../auth/clinic_access.dart';
import 'doctor_detail_screen.dart';
import 'doctor_form_screen.dart';
import 'doctor_repository.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});
  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final _repository = DoctorRepository();
  final _search = TextEditingController();
  List<Doctor> _doctors = <Doctor>[];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doctors = await _repository.getAll();
      if (mounted) setState(() => _doctors = doctors);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const DoctorFormScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _openDetail(Doctor doctor) async {
    try {
      final full = await _repository.getById(doctor.id);
      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => DoctorDetailScreen(doctor: full),
        ),
      );
      if (changed == true && mounted) _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _doctors
        .where(
          (doctor) =>
              doctor.fullName.toLowerCase().contains(query) ||
              (doctor.specialty ?? '').toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Doctores')),
      floatingActionButton:
          ClinicAccessScope.of(context)?.can('doctores', 'create') == true
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Nuevo doctor'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text('Doctores', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              'Administra perfiles profesionales y horarios de atencion.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
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
            else if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No hay doctores registrados.')),
              )
            else
              ...visible.map(
                (doctor) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.medical_services_outlined),
                    ),
                    title: Text(doctor.fullName),
                    subtitle: Text(
                      doctor.specialty?.isNotEmpty == true
                          ? doctor.specialty!
                          : 'Sin especialidad registrada',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDetail(doctor),
                  ),
                ),
              ),
            const SizedBox(height: 84),
          ],
        ),
      ),
    );
  }
}
