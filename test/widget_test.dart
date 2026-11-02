import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dental_care/core/config/app_config.dart';
import 'package:dental_care/features/auth/clinic_access.dart';
import 'package:dental_care/features/dashboard/dashboard_screen.dart';
import 'package:dental_care/features/modules/clinic_area_screen.dart';
import 'package:dental_care/features/modules/module_screen.dart';

void main() {
  final dentist = ClinicAccess.fromMap({
    'rol': 'doctor',
    'permisos': ['pacientes.read', 'pacientes.create', 'citas.read'],
  });
  final administrator = ClinicAccess(
    role: 'admin',
    permissions: ['usuarios.read'],
  );

  Widget withAccess(ClinicAccess? access, Widget child) => MaterialApp(
    builder: (context, navigator) =>
        ClinicAccessScope(access: access, child: navigator!),
    home: child,
  );

  const dashboard = DashboardScreen(
    config: AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
  );

  test('Odontologo conserva solo las acciones recibidas del servidor', () {
    expect(dentist.can('pacientes', 'create'), isTrue);
    expect(dentist.can('citas', 'read'), isTrue);
    expect(dentist.can('citas', 'create'), isFalse);
    expect(dentist.can('roles', 'update'), isFalse);
    expect(dentist.can('usuarios', 'read'), isFalse);
    expect(dentist.canOpenArea('administrador'), isFalse);
  });

  test('Un rol no autorizado no concede acceso aunque reciba permisos', () {
    final unknown = ClinicAccess(role: 'staff', permissions: ['usuarios.read']);
    expect(unknown.hasPanelAccess, isFalse);
    expect(unknown.can('usuarios', 'read'), isFalse);
    expect(unknown.canOpenArea('odontologo'), isFalse);
  });

  testWidgets('Odontologo solo ve su modulo y permisos de lectura', (
    tester,
  ) async {
    await tester.pumpWidget(withAccess(dentist, dashboard));
    expect(find.text('Administrador'), findsNothing);
    await tester.tap(find.text('Odontólogo'));
    await tester.pumpAndSettle();
    expect(find.text('Pacientes'), findsOneWidget);
    expect(find.text('Agenda medica y citas'), findsOneWidget);
    expect(find.text('Recetas'), findsNothing);
    expect(find.text('Usuarios'), findsNothing);
  });

  testWidgets('Navegacion directa al area administrativa tambien se bloquea', (
    tester,
  ) async {
    await tester.pumpWidget(
      withAccess(
        dentist,
        const ClinicAreaScreen(
          module: ClinicModule(
            'Administrador',
            '',
            Icons.settings,
            'administrador',
          ),
        ),
      ),
    );
    expect(find.text('Acceso restringido'), findsOneWidget);
    expect(find.text('Usuarios'), findsNothing);
  });

  testWidgets('Administrador ve ambos modulos', (tester) async {
    await tester.pumpWidget(withAccess(administrator, dashboard));
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Odontólogo'), findsOneWidget);
  });

  testWidgets('Sin permisos cargados no se muestran modulos', (tester) async {
    await tester.pumpWidget(withAccess(null, dashboard));
    expect(find.text('Administrador'), findsNothing);
    expect(find.text('Odontólogo'), findsNothing);
  });
}
