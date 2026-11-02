import 'package:flutter/material.dart';

import 'patient.dart';
import '../auth/clinic_access.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';
import 'patient_repository.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _repository = PatientRepository();
  final _search = TextEditingController();
  List<Patient> _patients = <Patient>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadPatients();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patients = await _repository.getAll();
      if (mounted) setState(() => _patients = patients);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Patient? patient]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PatientFormScreen(patient: patient),
      ),
    );
    if (changed == true) _loadPatients();
  }

  Future<void> _openDetail(Patient patient) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PatientDetailScreen(patient: patient),
      ),
    );
    if (changed == true) _loadPatients();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _patients
        .where(
          (patient) =>
              patient.fullName.toLowerCase().contains(query) ||
              (patient.email ?? '').toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      floatingActionButton:
          ClinicAccessScope.of(context)?.can('pacientes', 'create') == true
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Nuevo paciente'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadPatients,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Pacientes',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Administra las historias clinicas y datos de contacto.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o correo',
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
              _ErrorState(message: _error!, onRetry: _loadPatients)
            else if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No hay pacientes registrados.')),
              )
            else
              ...visible.map(
                (patient) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        patient.firstName.isEmpty
                            ? '?'
                            : patient.firstName.substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text(patient.fullName),
                    subtitle: Text(
                      patient.documentNumber?.isNotEmpty == true
                          ? 'Documento: ${patient.documentNumber}'
                          : patient.phone?.isNotEmpty == true
                          ? patient.phone!
                          : 'Sin documento ni telefono',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDetail(patient),
                  ),
                ),
              ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: <Widget>[
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
