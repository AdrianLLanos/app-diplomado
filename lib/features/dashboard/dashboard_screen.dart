import 'package:flutter/material.dart';
import '../../core/api/clinic_api.dart';

import '../../core/config/app_config.dart';
import '../auth/login_screen.dart';
import '../auth/clinic_access.dart';
import '../modules/clinic_area_screen.dart';
import '../modules/module_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.config});

  final AppConfig config;

  static const _modules = <ClinicModule>[
    ClinicModule(
      'Administrador',
      'Gestion de la clinica y administracion',
      Icons.admin_panel_settings_outlined,
      'administrador',
    ),
    ClinicModule(
      'Odontólogo',
      'Pacientes, citas y atencion clinica',
      Icons.medical_services_outlined,
      'odontologo',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final access = ClinicAccessScope.of(context);
    final modules = _modules
        .where((module) => access?.canOpenArea(module.endpoint) ?? false)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clínica San Martín'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 600
              ? 2
              : 1;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text(
                'Panel de control',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                access?.isAdministrator == true
                    ? 'Selecciona el modulo Administrador u Odontólogo.'
                    : 'Accede a tus funciones de Odontólogo.',
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 3.5 : 1.7,
                ),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return _ModuleCard(
                    module: module,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ClinicAreaScreen(module: module),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    ClinicApi.instance.clearSession();
    ClinicAccessSession.current.value = null;
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(config: config)),
      (route) => false,
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});
  final ClinicModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: const Color(0xFFE0F2F1),
                child: Icon(module.icon, color: const Color(0xFF006B72)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      module.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
