import 'dart:convert';

import 'package:app_finnegans/data/supabase/supabase_plan_formacion_repository.dart';
import 'package:app_finnegans/domain/modelos/plan_formacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

({SupabasePlanFormacionRepository repositorio, List<http.Request> requests})
_fixture(Future<http.Response> Function(http.Request) responder) {
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'https://test.supabase.co',
    'public-test-key',
    httpClient: MockClient((request) async {
      requests.add(request);
      return responder(request);
    }),
  );
  addTearDown(client.dispose);
  return (
    repositorio: SupabasePlanFormacionRepository(client),
    requests: requests,
  );
}

http.Response _json(http.Request request, Object cuerpo, [int status = 200]) =>
    http.Response(
      jsonEncode(cuerpo),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

/// Las 11 filas de una versión, con el plan por defecto salvo [cambios].
List<Map<String, Object>> _filas(
  String vigenteDesde, {
  Map<String, Map<String, num>> cambios = const {},
}) => [
  for (final seniority in Seniority.values)
    {
      'vigente_desde': vigenteDesde,
      'seniority': seniority.name,
      'negocio': seniority.negocio,
      'blandas': seniority.blandas,
      'libres': seniority.libres,
      'dictado': seniority.dictado,
      ...?cambios[seniority.name],
    },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Agrupa las filas por mes de vigencia', () async {
    final fixture = _fixture(
      (request) async => _json(request, [
        ..._filas('2026-07-01'),
        // PostgREST puede devolver numeric como texto.
        ..._filas(
          '2026-10-01',
          cambios: {
            'junior1': {'negocio': 6, 'blandas': 2},
          },
        ).map((fila) => {...fila, 'dictado': '${fila['dictado']}'}),
      ]),
    );

    final planes = await fixture.repositorio.getPlanes();

    final request = fixture.requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/rest/v1/plan_formacion');
    expect(
      request.url.queryParameters['select'],
      'vigente_desde,seniority,negocio,blandas,libres,dictado',
    );
    expect(planes.versiones.map((v) => v.vigenteDesde), [
      DateTime(2026, 7),
      DateTime(2026, 10),
    ]);
    expect(planes.vigenteEn(2026, 8), PlanFormacion.porDefecto());
    expect(planes.vigenteEn(2026, 10).horasRequeridas(Seniority.junior1), {
      TipoCurso.habilidadesDeNegocio: 6,
      TipoCurso.habilidadesBlandas: 2,
      TipoCurso.libresExploracion: 0,
      TipoCurso.dictadoCapacitaciones: 0,
    });
  });

  test('Una tabla vacía es el plan por defecto', () async {
    final fixture = _fixture((request) async => _json(request, []));

    final planes = await fixture.repositorio.getPlanes();

    expect(planes.versiones, isEmpty);
    expect(planes.vigenteEn(2026, 10), PlanFormacion.porDefecto());
  });

  test('Una versión incompleta no se completa con valores por defecto', () {
    final fixture = _fixture(
      (request) async => _json(request, _filas('2026-07-01').skip(1).toList()),
    );

    expect(fixture.repositorio.getPlanes(), throwsFormatException);
  });

  test('Un seniority desconocido es un error', () {
    final fixture = _fixture(
      (request) async => _json(request, [
        ..._filas('2026-07-01'),
        {..._filas('2026-07-01').first, 'seniority': 'director'},
      ]),
    );

    expect(fixture.repositorio.getPlanes(), throwsFormatException);
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
      fixture.repositorio.getPlanes(),
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
      final filas = jsonDecode(request.body) as List<dynamic>;
      return _json(request, [
        for (final fila in filas) {'seniority': (fila as Map)['seniority']},
      ], 201);
    });
    final plan = PlanFormacion({
      for (final seniority in Seniority.values)
        seniority: seniority == Seniority.junior1
            ? {
                TipoCurso.habilidadesDeNegocio: 6,
                TipoCurso.habilidadesBlandas: 2,
                TipoCurso.libresExploracion: 0,
                TipoCurso.dictadoCapacitaciones: 0,
              }
            : seniority.planFormacion,
    });

    await fixture.repositorio.guardarVersion(
      VersionPlanFormacion(vigenteDesde: DateTime(2026, 11, 20), plan: plan),
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
    final filas = (jsonDecode(request.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(filas, hasLength(11));
    expect(filas.map((fila) => fila['vigente_desde']).toSet(), {'2026-11-01'});
    expect(filas.firstWhere((fila) => fila['seniority'] == 'junior1'), {
      'vigente_desde': '2026-11-01',
      'seniority': 'junior1',
      'negocio': 6.0,
      'blandas': 2.0,
      'libres': 0.0,
      'dictado': 0.0,
    });
    // Sin columnas de auditoría: las completa el trigger de la base.
    expect(filas.first.containsKey('modificado_por'), isFalse);
  });

  test('Si no vuelven las 11 filas, el plan no se dio por guardado', () async {
    final fixture = _fixture((request) async => _json(request, [], 201));

    await expectLater(
      fixture.repositorio.guardarVersion(
        VersionPlanFormacion(
          vigenteDesde: DateTime(2026, 11),
          plan: PlanFormacion.porDefecto(),
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
      fixture.repositorio.guardarVersion(
        VersionPlanFormacion(
          vigenteDesde: DateTime(2026, 11),
          plan: PlanFormacion.porDefecto(),
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
