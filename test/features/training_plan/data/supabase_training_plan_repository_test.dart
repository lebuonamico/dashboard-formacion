import 'dart:convert';

import 'package:app_finnegans/features/training_plan/data/supabase_training_plan_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';

({SupabaseTrainingPlanRepository repositorio, List<http.Request> requests})
_fixture(Future<http.Response> Function(http.Request) respond) {
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'https://test.supabase.co',
    'public-test-key',
    httpClient: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
  );
  addTearDown(client.dispose);
  return (
    repositorio: SupabaseTrainingPlanRepository(client),
    requests: requests,
  );
}

http.Response _json(http.Request request, Object body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

/// Las 11 filas de una versión, con el plan por defecto salvo [changes].
List<Map<String, Object>> _rows(
  String validFrom, {
  Map<String, Map<String, num>> changes = const {},
}) => [
  for (final seniority in Seniority.values)
    {
      'vigente_desde': validFrom,
      'seniority': seniority.name,
      'negocio': TrainingPlanDefaults
          .hours[seniority]![CourseCategory.businessSkills]!,
      'blandas':
          TrainingPlanDefaults.hours[seniority]![CourseCategory.softSkills]!,
      'libres':
          TrainingPlanDefaults.hours[seniority]![CourseCategory.exploration]!,
      'dictado':
          TrainingPlanDefaults.hours[seniority]![CourseCategory.teaching]!,
      ...?changes[seniority.name],
    },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Agrupa las filas por mes de vigencia', () async {
    final fixture = _fixture(
      (request) async => _json(request, [
        ..._rows('2026-07-01'),
        // PostgREST puede devolver numeric como texto.
        ..._rows(
          '2026-10-01',
          changes: {
            'junior1': {'negocio': 6, 'blandas': 2},
          },
        ).map((row) => {...row, 'dictado': '${row['dictado']}'}),
      ]),
    );

    final plans = await fixture.repositorio.getPlans();

    final request = fixture.requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/rest/v1/plan_formacion');
    expect(
      request.url.queryParameters['select'],
      'vigente_desde,seniority,negocio,blandas,libres,dictado',
    );
    expect(plans.versions.map((v) => v.validFrom), [
      DateTime(2026, 7),
      DateTime(2026, 10),
    ]);
    expect(
      const TrainingPlanService().currentIn(plans, 2026, 8),
      TrainingPlanDefaults.plan,
    );
    expect(
      const TrainingPlanService()
          .currentIn(plans, 2026, 10)
          .hours[Seniority.junior1]!,
      {
        CourseCategory.businessSkills: 6,
        CourseCategory.softSkills: 2,
        CourseCategory.exploration: 0,
        CourseCategory.teaching: 0,
      },
    );
  });

  test('Una tabla vacía es el plan por defecto', () async {
    final fixture = _fixture((request) async => _json(request, []));

    final plans = await fixture.repositorio.getPlans();

    expect(plans.versions, isEmpty);
    expect(
      const TrainingPlanService().currentIn(plans, 2026, 10),
      TrainingPlanDefaults.plan,
    );
  });

  test('Una versión incompleta no se completa con valores por defecto', () {
    final fixture = _fixture(
      (request) async => _json(request, _rows('2026-07-01').skip(1).toList()),
    );

    expect(fixture.repositorio.getPlans(), throwsFormatException);
  });

  test('Un seniority desconocido es un error', () {
    final fixture = _fixture(
      (request) async => _json(request, [
        ..._rows('2026-07-01'),
        {..._rows('2026-07-01').first, 'seniority': 'director'},
      ]),
    );

    expect(fixture.repositorio.getPlans(), throwsFormatException);
  });

  test('Sin la tabla pide correr el script', () async {
    final fixture = _fixture(
      (request) async => _json(request, {
        'code': 'PGRST205',
        'message': "Could not find the table 'public.plan_formacion'",
        'details': null,
        'hint': null,
      }, 404),
    );

    await expectLater(
      fixture.repositorio.getPlans(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('supabase/plan_formacion.sql'),
        ),
      ),
    );
  });

  test('Guarda las 11 filas en un solo upsert por mes y seniority', () async {
    final fixture = _fixture((request) async {
      final rows = jsonDecode(request.body) as List<dynamic>;
      return _json(request, [
        for (final row in rows) {'seniority': (row as Map)['seniority']},
      ], 201);
    });
    final plan = TrainingPlan({
      for (final seniority in Seniority.values)
        seniority: seniority == Seniority.junior1
            ? {
                CourseCategory.businessSkills: 6,
                CourseCategory.softSkills: 2,
                CourseCategory.exploration: 0,
                CourseCategory.teaching: 0,
              }
            : TrainingPlanDefaults.hours[seniority]!,
    });

    await fixture.repositorio.saveVersion(
      TrainingPlanVersion(validFrom: DateTime(2026, 11, 20), plan: plan),
    );

    final request = fixture.requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/plan_formacion');
    expect(
      request.url.queryParameters['on_conflict'],
      'vigente_desde,seniority',
    );
    expect(request.url.queryParameters['select'], 'seniority');
    expect(request.headers['prefer'], contains('resolution=merge-duplicates'));
    final dataRows = (jsonDecode(request.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(dataRows, hasLength(11));
    expect(dataRows.map((row) => row['vigente_desde']).toSet(), {'2026-11-01'});
    expect(dataRows.firstWhere((row) => row['seniority'] == 'junior1'), {
      'vigente_desde': '2026-11-01',
      'seniority': 'junior1',
      'negocio': 6.0,
      'blandas': 2.0,
      'libres': 0.0,
      'dictado': 0.0,
    });
    // Sin columnas de auditoría: las completa el trigger de la base.
    expect(dataRows.first.containsKey('modificado_por'), isFalse);
  });

  test('Si no vuelven las 11 filas, el plan no se dio por guardado', () async {
    final fixture = _fixture((request) async => _json(request, [], 201));

    await expectLater(
      fixture.repositorio.saveVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 11),
          plan: TrainingPlanDefaults.plan,
        ),
      ),
      throwsFormatException,
    );
  });

  test('Sin permiso lo dice en lugar de un error genérico', () async {
    final fixture = _fixture(
      (request) async => _json(request, {
        'code': '42501',
        'message': 'new row violates row-level security policy',
        'details': null,
        'hint': null,
      }, 403),
    );

    await expectLater(
      fixture.repositorio.saveVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 11),
          plan: TrainingPlanDefaults.plan,
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('permiso para cambiar el plan'),
        ),
      ),
    );
  });
}
