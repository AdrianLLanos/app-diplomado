import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dental_care/features/auth/clinic_access.dart';
import 'package:dental_care/features/radiographs/radiograph.dart';
import 'package:dental_care/features/radiographs/radiograph_repository.dart';
import 'package:dental_care/features/radiographs/radiograph_list_screen.dart';
import 'package:dental_care/features/radiographs/radiograph_viewer_screen.dart';

class FakeRadiographs implements RadiographSource {
  List<RadiographStudy> studies = [];
  int listCalls = 0;
  int urlCalls = 0;
  bool failList = false;
  bool failUrl = false;
  String? requestedPatient;

  @override
  Future<List<RadiographStudy>> getStudies({
    String? patientId,
    int page = 0,
  }) async {
    listCalls++;
    requestedPatient = patientId;
    if (failList) throw StateError('Sin conexion');
    return studies;
  }

  @override
  Future<String> createViewingUrl(RadiographStudy study) async {
    urlCalls++;
    if (failUrl) throw StateError('Acceso denegado');
    return 'https://example.test/archivo.pdf?token=temporal';
  }
}

void main() {
  final access = ClinicAccess(
    role: 'doctor',
    permissions: ['radiografias.read'],
  );
  const ready = RadiographStudy(
    id: '1',
    patientName: 'Paciente de prueba',
    studyType: 'Panoramica',
    status: 'Completada',
    fileName: 'estudio.pdf',
    mimeType: 'application/pdf',
    storagePath: '1/estudio.pdf',
  );
  const pending = RadiographStudy(
    id: '2',
    patientName: 'Otro paciente de prueba',
    studyType: 'Panoramica',
    status: 'Pendiente',
  );

  Widget app(Widget home, {bool allowed = true}) => MaterialApp(
    builder: (context, child) =>
        ClinicAccessScope(access: allowed ? access : null, child: child!),
    home: home,
  );

  test('Lee archivos tanto de una relacion unica como de una lista', () {
    final row = <String, dynamic>{
      'id': '1',
      'tipo': 'Panoramica',
      'estado': 'Completada',
      'pacientes': {'nombres': 'Paciente', 'apellidos': 'Prueba'},
      'radiografias': {
        'nombre': 'estudio.pdf',
        'tipo': 'application/pdf',
        'storage_path': '1/estudio.pdf',
      },
    };
    expect(RadiographStudy.fromMap(row).isPdf, isTrue);
    row['radiografias'] = [row['radiografias']];
    expect(RadiographStudy.fromMap(row).hasFile, isTrue);
    row['radiografias'] = [];
    expect(RadiographStudy.fromMap(row).hasFile, isFalse);
  });

  testWidgets('Sin permiso no consulta datos ni genera enlaces', (
    tester,
  ) async {
    final source = FakeRadiographs();
    await tester.pumpWidget(
      app(RadiographListScreen(source: source), allowed: false),
    );
    await tester.pumpAndSettle();
    expect(source.listCalls, 0);
    expect(source.urlCalls, 0);
    expect(
      find.text('No tienes permiso para consultar radiografias.'),
      findsOneWidget,
    );
  });

  testWidgets('Archivo disponible abre visor PDF; pendientes no se abren', (
    tester,
  ) async {
    final source = FakeRadiographs()..studies = [ready, pending];
    await tester.pumpWidget(
      app(RadiographListScreen(source: source, patientId: 'paciente-id')),
    );
    await tester.pumpAndSettle();
    expect(source.requestedPatient, 'paciente-id');
    expect(find.text('Radiografia pendiente'), findsOneWidget);
    expect(find.text('Visualizar radiografia'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.text('Visualizar radiografia'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir PDF'), findsOneWidget);
    expect(source.urlCalls, 1);
  });

  testWidgets('Lista vacia y recuperacion de un error de conexion', (
    tester,
  ) async {
    final source = FakeRadiographs()..failList = true;
    await tester.pumpWidget(app(RadiographListScreen(source: source)));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    source.failList = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      find.text('No hay radiografias registradas para tus pacientes.'),
      findsOneWidget,
    );
  });

  testWidgets('Enlace rechazado permite renovar acceso', (tester) async {
    final source = FakeRadiographs()..failUrl = true;
    await tester.pumpWidget(
      app(RadiographViewerScreen(study: ready, source: source)),
    );
    await tester.pumpAndSettle();
    source.failUrl = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir PDF'), findsOneWidget);
    expect(source.urlCalls, 2);
  });

  testWidgets('Acceso directo al visor sin permiso no obtiene archivo', (
    tester,
  ) async {
    final source = FakeRadiographs();
    await tester.pumpWidget(
      app(RadiographViewerScreen(study: ready, source: source), allowed: false),
    );
    await tester.pumpAndSettle();
    expect(source.urlCalls, 0);
    expect(
      find.text('No tienes permiso para ver esta radiografia.'),
      findsOneWidget,
    );
  });
}
