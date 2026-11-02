import 'package:flutter/material.dart';

import '../appointments/appointment_list_screen.dart';
import '../doctors/doctor_list_screen.dart';
import '../patients/patient_list_screen.dart';
import '../auth/clinic_access.dart';
import '../radiographs/radiograph_list_screen.dart';
import 'module_screen.dart';
import 'api_records_screen.dart';

class ClinicAreaScreen extends StatelessWidget {
  const ClinicAreaScreen({super.key, required this.module});

  final ClinicModule module;

  static const _administratorFunctions = <ClinicModule>[
    ClinicModule(
      'Pacientes',
      'Datos y registro de pacientes',
      Icons.people_alt_outlined,
      'pacientes',
    ),
    ClinicModule(
      'Doctores',
      'Profesionales y horarios de atencion',
      Icons.medical_services_outlined,
      'doctores',
    ),
    ClinicModule(
      'Citas',
      'Reservas de pacientes',
      Icons.event_available_outlined,
      'citas',
    ),
    ClinicModule(
      'Antecedentes clinicos',
      'Historia y antecedentes del paciente',
      Icons.assignment_outlined,
      'antecedentes',
    ),
    ClinicModule(
      'Recetas',
      'Prescripciones de tratamiento',
      Icons.receipt_long_outlined,
      'recetas',
    ),
    ClinicModule(
      'Radiografias',
      'Solicitudes y estudios dentales',
      Icons.image_outlined,
      'radiografias',
    ),
    ClinicModule(
      'Usuarios',
      'Cuentas de acceso a la clinica',
      Icons.manage_accounts_outlined,
      'usuarios',
    ),
    ClinicModule(
      'Roles y permisos',
      'Control de acceso de Administrador y Odontólogo',
      Icons.settings_outlined,
      'roles',
    ),
  ];

  static const _dentistFunctions = <ClinicModule>[
    ClinicModule(
      'Pacientes',
      'Historias clinicas y datos de contacto',
      Icons.people_alt_outlined,
      'pacientes',
    ),
    ClinicModule(
      'Agenda medica y citas',
      'Consulta de citas autorizadas',
      Icons.calendar_month_outlined,
      'citas',
    ),
    ClinicModule(
      'Antecedentes clinicos',
      'Historia y antecedentes del paciente',
      Icons.assignment_outlined,
      'antecedentes',
    ),
    ClinicModule(
      'Recetas',
      'Prescripciones de tratamiento',
      Icons.receipt_long_outlined,
      'recetas',
    ),
    ClinicModule(
      'Visualizar radiografias',
      'Consulta los estudios de tus pacientes',
      Icons.image_outlined,
      'radiografias',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final access = ClinicAccessScope.of(context);
    if (!(access?.canOpenArea(module.endpoint) ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso restringido')),
        body: const Center(
          child: Text('No tienes permiso para acceder a este modulo.'),
        ),
      );
    }
    final availableFunctions = module.endpoint == 'administrador'
        ? _administratorFunctions
        : _dentistFunctions;
    final functions = availableFunctions.where(
      (function) => access?.can(function.endpoint, 'read') ?? false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(module.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            module.description,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...functions.map(
            (function) => Card(
              child: ListTile(
                leading: Icon(
                  function.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(function.name),
                subtitle: Text(function.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _functionScreen(function),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _functionScreen(ClinicModule function) {
    switch (function.endpoint) {
      case 'pacientes':
        return const PatientListScreen();
      case 'doctores':
        return const DoctorListScreen();
      case 'citas':
        return const AppointmentListScreen();
      case 'radiografias':
        return const RadiographListScreen();
      case 'antecedentes':
      case 'recetas':
      case 'usuarios':
      case 'roles':
        return ApiRecordsScreen(
          resource: function.endpoint,
          title: function.name,
        );
      default:
        return ModuleScreen(module: function);
    }
  }
}
