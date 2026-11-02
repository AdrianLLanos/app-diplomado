import 'package:flutter/material.dart';

import 'patient.dart';
import 'patient_repository.dart';

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key, this.patient});

  final Patient? patient;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = PatientRepository();
  late final TextEditingController _firstName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  DateTime? _birthDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;
    _firstName = TextEditingController(text: patient?.fullName ?? '');
    _phone = TextEditingController(text: patient?.phone ?? '');
    _email = TextEditingController(text: patient?.email ?? '');
    _address = TextEditingController(text: patient?.address ?? '');
    _birthDate = patient?.birthDate;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1995),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repository.save(
        Patient(
          id: widget.patient?.id ?? '',
          firstName: _firstName.text,
          lastName: '',
          birthDate: _birthDate,
          phone: _phone.text,
          email: _email.text,
          address: _address.text,
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
      title: Text(
        widget.patient == null ? 'Nuevo paciente' : 'Editar paciente',
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Datos personales',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _field(_firstName, 'Nombre completo', validator: _validateName),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _selectBirthDate,
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                _birthDate == null
                    ? 'Seleccionar fecha de nacimiento'
                    : 'Nacimiento: ${_formatDate(_birthDate!)}',
              ),
            ),
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
            const SizedBox(height: 12),
            _field(_address, 'Direccion', maxLines: 2),
            const SizedBox(height: 12),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Guardando...' : 'Guardar paciente'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
    validator: validator,
  );

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Este campo es obligatorio';
    if (name.length < 2) return 'Ingresa al menos 2 caracteres';
    if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ .'-]+$").hasMatch(name)) {
      return 'Usa solo letras y espacios';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Ingresa un telefono valido de 7 a 15 digitos';
    }
    if (!RegExp(r'^[0-9+() .-]+$').hasMatch(phone)) {
      return 'El telefono contiene caracteres no validos';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa un correo electronico';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
        ? null
        : 'Ingresa un correo valido';
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
