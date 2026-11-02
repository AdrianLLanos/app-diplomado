import 'package:flutter/material.dart';

import 'doctor.dart';
import 'doctor_repository.dart';

class DoctorFormScreen extends StatefulWidget {
  const DoctorFormScreen({super.key, this.doctor});
  final Doctor? doctor;

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = DoctorRepository();
  late final TextEditingController _name;
  late final TextEditingController _specialty;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final doctor = widget.doctor;
    _name = TextEditingController(text: doctor?.fullName ?? '');
    _specialty = TextEditingController(text: doctor?.specialty ?? '');
    _phone = TextEditingController(text: doctor?.phone ?? '');
    _email = TextEditingController(text: doctor?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repository.save(
        Doctor(
          id: widget.doctor?.id ?? '',
          fullName: _name.text,
          specialty: _specialty.text,
          phone: _phone.text,
          email: _email.text,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.doctor == null ? 'Nuevo doctor' : 'Editar doctor'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            'Perfil profesional',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _field(_name, 'Nombre completo', validator: _validateName),
          const SizedBox(height: 12),
          _field(_specialty, 'Especialidad', validator: _validateSpecialty),
          const SizedBox(height: 12),
          _field(
            _phone,
            'Telefono',
            keyboardType: TextInputType.phone,
            validator: _validatePhone,
          ),
          const SizedBox(height: 12),
          _field(
            _email,
            'Correo electronico',
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando...' : 'Guardar doctor'),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
    validator: validator,
  );

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.length < 3) return 'Ingresa el nombre completo';
    if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ .'-]+$").hasMatch(name))
      return 'Usa solo letras y espacios';
    return null;
  }

  String? _validateSpecialty(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Ingresa la especialidad' : null;

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7 && digits.length <= 15
        ? null
        : 'Ingresa un telefono valido de 7 a 15 digitos';
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa un correo electronico';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
        ? null
        : 'Ingresa un correo valido';
  }
}
