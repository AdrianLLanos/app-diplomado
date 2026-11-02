import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dental_care/core/api/clinic_api.dart';
import 'package:dental_care/core/config/app_config.dart';
import 'package:dental_care/features/auth/clinic_access.dart';
import 'package:dental_care/features/patients/patient.dart';
import 'package:dental_care/features/patients/patient_repository.dart';
import 'package:dental_care/features/doctors/doctor_schedule.dart';
import 'package:dental_care/features/appointments/appointment.dart';
import 'package:dental_care/features/appointments/appointment_repository.dart';
import 'package:dental_care/features/radiographs/radiograph.dart';
import 'package:dental_care/features/radiographs/radiograph_repository.dart';

const config = AppConfig(apiBaseUrl: 'https://clinic.test/api/v1');
http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

ClinicApi client(Future<http.Response> Function(http.Request) handler) =>
    ClinicApi(
      config: config,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          expect(jsonDecode(request.body), {
            'correo': 'doctor@example.test',
            'contrasena': 'password-test',
          });
          expect(request.headers['Authorization'], isNull);
          return json({'token': 'session-test-token'});
        }
        if (request.url.path.endsWith('/session')) {
          expect(request.headers['Authorization'], 'Bearer session-test-token');
          return json({
            'user': {
              'id': 17,
              'roles': ['Doctor'],
              'permissions': ['pacientes.read', 'radiografias.read'],
            },
            'companyId': '3',
          });
        }
        return handler(request);
      }),
    );

Future<void> login(ClinicApi api) =>
    api.login('doctor@example.test', 'password-test');

void main() {
  test(
    'Uses web accounts, Bearer auth and company isolation for paginated patients',
    () async {
      var calls = 0;
      final api = client((request) async {
        calls++;
        expect(request.url.path, '/api/v1/pacientes');
        expect(request.headers['Authorization'], 'Bearer session-test-token');
        expect(request.headers['X-Company-ID'], '3');
        final page = int.parse(request.url.queryParameters['page']!);
        expect(page, calls - 1);
        return json({
          'total': 2,
          'rows': [
            {
              'id': page + 1,
              'nombre': 'Paciente $page',
              'correo': 'paciente$page@example.test',
            },
          ],
        });
      });
      final user = await api.login('doctor@example.test', 'password-test');
      expect(ClinicAccess.fromApi(user).isDentist, isTrue);
      final patients = await PatientRepository(client: api).getAll();
      expect(patients.map((p) => p.id), ['1', '2']);
      expect(calls, 2);
    },
  );

  test(
    'Patient saves use the web schema without unsupported fields or activation on edits',
    () async {
      final api = client((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/pacientes/21');
        final body = jsonDecode(request.body) as Map;
        expect(body['nombre'], 'Ana Maria Perez');
        expect(body['correo'], 'ana@example.test');
        expect(body.containsKey('numero_documento'), isFalse);
        expect(body.containsKey('estado'), isFalse);
        expect(body.containsKey('nombres'), isFalse);
        return json({'id': 21});
      });
      await login(api);
      await PatientRepository(client: api).save(
        const Patient(
          id: '21',
          firstName: 'Ana Maria',
          lastName: 'Perez',
          email: 'ana@example.test',
        ),
      );
    },
  );

  test(
    '401 expires local session and subsequent requests cannot reuse its token',
    () async {
      var expired = 0;
      var calls = 0;
      final api = client((request) async {
        calls++;
        return json({'message': 'La sesión expiró'}, 401);
      });
      api.onSessionExpired = () => expired++;
      await login(api);
      await expectLater(
        api.request('GET', 'pacientes'),
        throwsA(
          isA<ClinicApiException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
      expect(expired, 1);
      expect(api.userId, isNull);
      await expectLater(
        api.request('GET', 'pacientes'),
        throwsA(isA<ClinicApiException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'Permission errors preserve the session and explain the server rejection',
    () async {
      final api = client(
        (request) async => json({'message': 'Paciente no asignado'}, 403),
      );
      await login(api);
      await expectLater(
        api.request('GET', 'pacientes'),
        throwsA(
          isA<ClinicApiException>().having(
            (e) => e.message,
            'message',
            'Paciente no asignado',
          ),
        ),
      );
      expect(api.userId, '17');
    },
  );

  test(
    'Appointments retain clinical date and exact duration from the web',
    () async {
      final item = Appointment.fromApi({
        'id': 2,
        'usuario_id': 21,
        'medico_id': 17,
        'fecha_cita': '2026-10-28',
        'hora_inicio': '09:15:00',
        'hora_fin': '09:35:00',
        'motivo_consulta': 'Control',
      });
      expect(item.endsAt.difference(item.startsAt).inMinutes, 20);
      expect(item.toApi(), {
        'usuario_id': '21',
        'medico_id': '17',
        'fecha_cita': '2026-10-28',
        'hora_inicio': '09:15',
        'hora_fin': '09:35',
        'motivo_consulta': 'Control',
      });
      final api = client((request) async {
        expect(request.url.path, '/api/v1/slots');
        expect(request.url.queryParameters, {
          'medico': '17',
          'fecha': '2026-10-28',
          'exclude': '2',
        });
        return json([
          {'inicio': '09:15', 'fin': '09:35'},
        ]);
      });
      await login(api);
      final slots = await AppointmentRepository(
        client: api,
      ).slots('17', DateTime(2026, 10, 28), excludeId: '2');
      expect(slots.single['fin'], '09:35');
    },
  );

  test(
    'Schedule translates web day, slot type, numeric IDs and inactive state',
    () {
      final schedule = DoctorSchedule.fromApi({
        'id': 8,
        'usuario_id': 17,
        'dia_semana': 'Wednesday',
        'hora_inicio': '08:00:00',
        'hora_fin': '12:00:00',
        'duracion_media_cita': 5,
        'tipo_turno': 'Sequential',
        'estado': '0',
      });
      expect(schedule.weekday, 'Miercoles');
      expect(schedule.active, isFalse);
      expect(schedule.toApi(), {
        'usuario_id': '17',
        'dia_semana': 'Wednesday',
        'hora_inicio': '08:00',
        'hora_fin': '12:00',
        'duracion_media_cita': 5,
        'tipo_turno': 'Sequential',
        'estado': '0',
      });
    },
  );

  test(
    'Radiography requests and CERPAX links reuse existing API contracts',
    () async {
      var calls = 0;
      final api = client((request) async {
        calls++;
        if (calls == 1) {
          expect(request.url.path, '/api/v1/radiographs');
          expect(jsonDecode(request.body), {
            'paciente_id': '21',
            'tipo': 'Panoramica',
            'indicaciones': 'Control',
          });
          return json({'id': 5}, 201);
        }
        expect(request.url.path, '/api/v1/radiographs/5/access');
        expect(jsonDecode(request.body), {'horas': 24});
        return json({
          'url': 'https://clinic.test/carga-radiografia#temporary',
          'vence_en': '2026-10-28T12:00:00Z',
        }, 201);
      });
      await login(api);
      final repo = RadiographRepository(client: api);
      await repo.create(patientId: '21', type: 'Panoramica', notes: 'Control');
      expect(
        (await repo.generateAccess('5'))['url'],
        contains('/carga-radiografia#'),
      );
    },
  );

  test(
    'Temporary file JSON link works without redirecting API credentials',
    () async {
      final api = client((request) async {
        if (request.url.host == 'clinic.test') {
          expect(request.url.queryParameters, {'delivery': 'json'});
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], 'Bearer session-test-token');
          expect(request.headers['X-Company-ID'], '3');
          return json({
            'signedUrl': 'https://storage.test/private/study?token=signed',
          });
        }
        expect(request.url.host, 'storage.test');
        expect(request.headers['Authorization'], isNull);
        expect(request.headers['X-Company-ID'], isNull);
        return http.Response.bytes(
          [137, 80, 78, 71],
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      await login(api);
      final file = await api.file('radiographs/5/file');
      expect(file.mimeType, 'image/png');
      expect(file.bytes, [137, 80, 78, 71]);
    },
  );

  test('Direct file responses remain supported', () async {
    final api = client((request) async {
      expect(request.url.queryParameters, {'delivery': 'json'});
      return http.Response.bytes(
        [37, 80, 68, 70],
        200,
        headers: {'content-type': 'application/pdf'},
      );
    });
    await login(api);
    expect((await api.file('radiographs/5/file')).mimeType, 'application/pdf');
  });

  test(
    'Invalid temporary file links are rejected before downloading',
    () async {
      for (final metadata in [
        <String, Object>{},
        {'signedUrl': 'http://storage.test/study'},
        {'signedUrl': 'https://user:password@storage.test/study'},
        {'signedUrl': 'https:study'},
      ]) {
        var calls = 0;
        final api = client((request) async {
          calls++;
          return json(metadata);
        });
        await login(api);
        await expectLater(
          api.file('radiographs/5/file'),
          throwsA(isA<ClinicApiException>()),
        );
        expect(calls, 1);
      }
    },
  );

  test(
    'Private file redirect never forwards API credentials to Supabase Storage',
    () async {
      final api = client((request) async {
        if (request.url.host == 'clinic.test') {
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], 'Bearer session-test-token');
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://storage.test/private/study?token=signed',
            },
          );
        }
        expect(request.url.host, 'storage.test');
        expect(request.headers['Authorization'], isNull);
        expect(request.headers['X-Company-ID'], isNull);
        return http.Response.bytes(
          [37, 80, 68, 70],
          200,
          headers: {'content-type': 'application/pdf'},
        );
      });
      await login(api);
      final study = RadiographStudy.fromApi({
        'id': 5,
        'paciente': 'Ana',
        'tipo': 'Panoramica',
        'estado': 'Completada',
        'archivo_id': 9,
        'archivo_nombre': 'estudio.pdf',
      });
      expect(study.hasFile, isTrue);
      final file = await RadiographRepository(client: api).getFile(study);
      expect(file.mimeType, 'application/pdf');
      expect(file.bytes, [37, 80, 68, 70]);
    },
  );

  test(
    'Web role permissions map doctor and schedule resources without trusting bypass',
    () {
      final doctor = ClinicAccess.fromApi({
        'roles': ['Doctor'],
        'permissions': ['medicos.read', 'horarios.update'],
        'bypass': true,
      });
      expect(doctor.can('doctores', 'read'), isTrue);
      expect(doctor.can('horarios', 'update'), isTrue);
      expect(doctor.can('usuarios', 'read'), isFalse);
      final admin = ClinicAccess.fromApi({
        'roles': ['Super Admin'],
        'permissions': [],
      });
      expect(admin.can('usuarios', 'read'), isTrue);
      final patient = ClinicAccess.fromApi({
        'roles': ['Patient'],
        'permissions': ['pacientes.read'],
      });
      expect(patient.hasPanelAccess, isFalse);
    },
  );
}
