import 'dart:convert';

import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/data/supabase/supabase_repositories.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _seedLocalData() {
  SharedPreferences.setMockInitialValues({
    'formacion_empleados': jsonEncode([
      {
        'legajo': 'LOCAL-ONLY',
        'nombre': 'Empleado local',
        'apellido': 'Ficticio',
        'seniority': 'trainee',
        'area': 'Sector local',
        'mail': 'local@example.com',
        'equipo': 'Equipo local',
        'gerente': 'Gerente local',
      },
    ]),
    'formacion_cursos': jsonEncode([
      {
        'id': 'LOCAL-COURSE',
        'nombre': 'Curso local ficticio',
        'tipo': 'habilidadesDeNegocio',
        'areaCurso': 'Área local',
        'instructorLegajo': 'LOCAL-ONLY',
        'cargaHorariaHs': 2,
      },
    ]),
    'formacion_carga_de_horas_crm': jsonEncode([
      {
        'id': 'LOCAL-HOURS',
        'cursoNombre': 'Curso local ficticio',
        'cursoId': 'LOCAL-COURSE',
        'empleadoLegajo': 'LOCAL-ONLY',
        'fecha': '2025-01-15',
        'horasTotales': 2,
        'tipo': 'tomada',
      },
    ]),
    'formacion_certificaciones_moodle': jsonEncode([
      {
        'legajo': 'LOCAL-ONLY',
        'cursoNombre': 'Curso local ficticio',
        'cursoId': 'LOCAL-COURSE',
        'finalizoCurso': true,
        'fechaFinalizacion': '2025-01-15',
      },
    ]),
  });
}

ProviderContainer _remoteContainer(SupabaseClient client) => ProviderContainer(
  overrides: [supabaseClientProvider.overrideWithValue(client)],
  // Disable Riverpod's retries so each request has one deterministic result.
  retry: (_, _) => null,
);

void _expectRemoteRepositories(ProviderContainer container) {
  expect(
    container.read(empleadosRepositoryProvider),
    isA<SupabaseEmpleadosRepository>(),
  );
  expect(
    container.read(cursosRepositoryProvider),
    isA<SupabaseCursosRepository>(),
  );
  expect(
    container.read(cargaDeHorasCRMRepositoryProvider),
    isA<SupabaseCargaDeHorasCRMRepository>(),
  );
  expect(
    container.read(certificacionesMoodleRepositoryProvider),
    isA<SupabaseCertificacionesMoodleRepository>(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(_seedLocalData);

  test(
    'USE_SUPABASE=false selects explicit local repositories without a client',
    () async {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith(
            (ref) => throw StateError('El modo local no debe crear Supabase'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(empleadosRepositoryProvider),
        isA<LocalEmpleadosRepository>(),
      );
      expect(
        container.read(cursosRepositoryProvider),
        isA<LocalCursosRepository>(),
      );
      expect(
        container.read(cargaDeHorasCRMRepositoryProvider),
        isA<LocalCargaDeHorasCRMRepository>(),
      );
      expect(
        container.read(certificacionesMoodleRepositoryProvider),
        isA<LocalCertificacionesMoodleRepository>(),
      );
      expect(
        (await container.read(empleadosProvider.future)).single.legajo,
        'LOCAL-ONLY',
      );
      expect(
        (await container.read(cursosProvider.future)).single.id,
        'LOCAL-COURSE',
      );
      expect(
        (await container.read(cargasDeHorasCRMProvider.future)).single.id,
        'LOCAL-HOURS',
      );
      expect(
        (await container.read(
          certificacionesMoodleProvider.future,
        )).single.legajo,
        'LOCAL-ONLY',
      );
    },
    skip: SupabaseConfig.enabled,
  );

  group('USE_SUPABASE=true makes Supabase the only active data source', () {
    for (final status in [403, 500]) {
      test(
        'All repositories and data providers propagate HTTP $status despite local data',
        () async {
          final requests = <http.Request>[];
          final code = status == 403 ? '42501' : 'XX000';
          final client = SupabaseClient(
            'https://test.supabase.co',
            'public-test-key',
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode({'message': 'remote failure', 'code': code}),
                status,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }),
          );
          addTearDown(client.dispose);
          final container = _remoteContainer(client);
          addTearDown(container.dispose);
          _expectRemoteRepositories(container);
          final failure = throwsA(
            isA<PostgrestException>()
                .having((error) => error.code, 'code', code)
                .having((error) => error.message, 'message', 'remote failure'),
          );

          await expectLater(
            container.read(empleadosRepositoryProvider).getEmpleados(),
            failure,
          );
          await expectLater(
            container.read(cursosRepositoryProvider).getCursos(),
            failure,
          );
          await expectLater(
            container
                .read(cargaDeHorasCRMRepositoryProvider)
                .getCargasDeHoras(),
            failure,
          );
          await expectLater(
            container
                .read(certificacionesMoodleRepositoryProvider)
                .getCertificaciones(),
            failure,
          );
          await expectLater(container.read(empleadosProvider.future), failure);
          await expectLater(container.read(cursosProvider.future), failure);
          await expectLater(
            container.read(cargasDeHorasCRMProvider.future),
            failure,
          );
          await expectLater(
            container.read(certificacionesMoodleProvider.future),
            failure,
          );
          expect(container.read(empleadosProvider).hasError, isTrue);
          expect(container.read(cursosProvider).hasError, isTrue);
          expect(container.read(cargasDeHorasCRMProvider).hasError, isTrue);
          expect(
            container.read(certificacionesMoodleProvider).hasError,
            isTrue,
          );
          expect(requests.map((request) => request.url.path).toSet(), {
            '/rest/v1/empleados',
            '/rest/v1/cursos',
            '/rest/v1/horas_capacitacion',
            '/rest/v1/finalizaciones_cursos',
          });
          expect(requests.every((request) => request.method == 'GET'), isTrue);
        },
      );
    }

    test(
      'Empty remote tables remain empty despite populated preferences',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-test-key',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final container = _remoteContainer(client);
        addTearDown(container.dispose);
        _expectRemoteRepositories(container);

        expect(await container.read(empleadosProvider.future), isEmpty);
        expect(await container.read(cursosProvider.future), isEmpty);
        expect(await container.read(cargasDeHorasCRMProvider.future), isEmpty);
        expect(
          await container.read(certificacionesMoodleProvider.future),
          isEmpty,
        );
        expect(requests.length, 4);
      },
    );

    test(
      'Repository filters use the physical columns in remote GETs',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-test-key',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final container = _remoteContainer(client);
        addTearDown(container.dispose);

        await container
            .read(empleadosRepositoryProvider)
            .getEmpleados(
              legajo: '10',
              equipo: 'Equipo remoto',
              sector: 'Sector remoto',
            );
        expect(requests.last.url.queryParameters['legajo'], 'eq.10');
        expect(
          requests.last.url.queryParameters['equipo_general'],
          'eq.Equipo remoto',
        );
        expect(requests.last.url.queryParameters['sector'], 'eq.Sector remoto');

        await container.read(cursosRepositoryProvider).getCursos(id: '107');
        expect(requests.last.url.queryParameters['id_curso'], 'eq.107');

        await container
            .read(cargaDeHorasCRMRepositoryProvider)
            .getCargasDeHoras(
              empleadoLegajo: '10',
              cursoId: '107',
              desde: DateTime(2025, 1),
              hasta: DateTime(2025, 2),
            );
        expect(requests.last.url.queryParameters['legajo'], 'eq.10');
        expect(requests.last.url.queryParameters['curso_id'], 'eq.107');
        expect(
          requests.last.url.queryParametersAll['fecha'],
          containsAll([
            'gte.2025-01-01T00:00:00.000',
            'lt.2025-02-01T00:00:00.000',
          ]),
        );

        await container
            .read(certificacionesMoodleRepositoryProvider)
            .getCertificaciones(legajo: '10', cursoId: '107');
        expect(requests.last.url.queryParameters['legajo'], 'eq.10');
        expect(requests.last.url.queryParameters['curso_id'], 'eq.107');
        expect(requests.map((request) => request.url.path), [
          '/rest/v1/empleados',
          '/rest/v1/cursos',
          '/rest/v1/horas_capacitacion',
          '/rest/v1/finalizaciones_cursos',
        ]);
      },
    );

    test('Course view models preserve auxiliary employee errors', () async {
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          final denied = request.url.path.endsWith('/empleados');
          return http.Response(
            denied ? '{"message":"employees denied","code":"42501"}' : '[]',
            denied ? 403 : 200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final container = _remoteContainer(client);
      addTearDown(container.dispose);

      expect(container.read(cursosConInstructorProvider).isLoading, isTrue);
      await expectLater(
        container.read(empleadosProvider.future),
        throwsA(isA<PostgrestException>()),
      );
      expect(await container.read(cursosProvider.future), isEmpty);
      await container.pump();

      final state = container.read(cursosConInstructorProvider);
      expect(state.hasError, isTrue);
      expect(
        state.error,
        isA<PostgrestException>().having(
          (error) => error.message,
          'message',
          'employees denied',
        ),
      );
    });

    for (final table in ['empleados', 'cursos']) {
      test('Hours view models preserve auxiliary $table errors', () async {
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-test-key',
          httpClient: MockClient((request) async {
            final denied = request.url.path.endsWith('/$table');
            return http.Response(
              denied
                  ? jsonEncode({'message': '$table denied', 'code': '42501'})
                  : '[]',
              denied ? 403 : 200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final container = _remoteContainer(client);
        addTearDown(container.dispose);

        expect(
          container.read(cargasDeHorasCompletasProvider).isLoading,
          isTrue,
        );
        if (table == 'empleados') {
          await expectLater(
            container.read(empleadosProvider.future),
            throwsA(isA<PostgrestException>()),
          );
          expect(await container.read(cursosProvider.future), isEmpty);
        } else {
          await expectLater(
            container.read(cursosProvider.future),
            throwsA(isA<PostgrestException>()),
          );
          expect(await container.read(empleadosProvider.future), isEmpty);
        }
        expect(await container.read(cargasDeHorasCRMProvider.future), isEmpty);
        await container.pump();

        final state = container.read(cargasDeHorasCompletasProvider);
        expect(state.hasError, isTrue);
        expect(
          state.error,
          isA<PostgrestException>().having(
            (error) => error.message,
            'message',
            '$table denied',
          ),
        );
      });
    }
  }, skip: !SupabaseConfig.enabled);
}
