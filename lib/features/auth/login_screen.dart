import 'package:flutter/material.dart';
import '../../core/api/clinic_api.dart';

import '../../core/config/app_config.dart';
import '../dashboard/dashboard_screen.dart';
import 'clinic_access.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.config});
  final AppConfig config;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      ClinicAccessSession.current.value = null;
      if (!widget.config.isConfigured) {
        throw const ClinicApiException(
          'Configura API_BASE_URL con la direccion HTTPS de tu sistema web.',
        );
      }
      final user = await ClinicApi.instance.login(
        _email.text.trim(),
        _password.text,
      );
      final access = ClinicAccess.fromApi(user);
      if (!access.hasPanelAccess) {
        ClinicApi.instance.clearSession();
        throw const ClinicApiException(
          'Esta app permite el acceso a Administrador y Odontologo. Solicita el rol correspondiente en el sistema web.',
        );
      }
      ClinicAccessSession.current.value = access;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DashboardScreen(config: widget.config),
        ),
      );
    } on ClinicApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      ClinicApi.instance.clearSession();
      if (mounted)
        setState(() => _error = 'No se pudo iniciar sesion en el sistema web.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFE0F2F1), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: Color(0xFF006B72),
                          child: Icon(
                            Icons.health_and_safety_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Clínica San Martín',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF006B72),
                              ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sistema de gestion de clinica dental',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electronico',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            return RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(email)
                                ? null
                                : 'Ingresa un correo valido';
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contrasena',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu contrasena';
                            }
                            return value.length < 6
                                ? 'La contrasena debe tener al menos 6 caracteres'
                                : null;
                          },
                        ),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading ? null : _login,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: const Color(0xFF006B72),
                          ),
                          child: Text(
                            _loading ? 'Verificando...' : 'Iniciar sesion',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
