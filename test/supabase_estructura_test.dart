import 'dart:convert';

import 'package:app_finnegans/data/supabase/supabase_estructura_repository.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

({SupabaseOrgStructureRepository repositorio, List<http.Request> requests})
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
    repositorio: SupabaseOrgStructureRepository(client),
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

http.Response _error(http.Request request, String code) => _json(request, {
  'code': code,
  'message': 'error $code',
  'details': null,
  'hint': null,
}, code == '23505' ? 409 : 403);

String _table(http.Request request) =>
    request.url.path.replaceFirst('/rest/v1/', '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lee las cuatro tablas y arma la estructura con sus líderes', () async {
    final fixture = _fixture((request) async {
      return switch (_table(request)) {
        'areas' => _json(request, [
          {'id': 1, 'nombre': 'PRODUCTOS TECNOLÓGICOS'},
          {'id': 2, 'nombre': 'SERVICIOS'},
        ]),
        'equipos' => _json(request, [
          {'id': 10, 'area_id': 1, 'nombre': 'PLATAFORMA CORE'},
        ]),
        'area_lideres' => _json(request, [
          {'area_id': 1, 'email': 'area@finnegans.com'},
        ]),
        'equipo_lideres' => _json(request, [
          {'equipo_id': 10, 'email': 'uno@finnegans.com'},
          {'equipo_id': 10, 'email': 'dos@finnegans.com'},
        ]),
        _ => throw StateError('Request inesperado: ${request.url}'),
      };
    });

    final structure = await fixture.repositorio.getStructure();

    expect(fixture.requests.map(_table).toSet(), {
      'areas',
      'equipos',
      'area_lideres',
      'equipo_lideres',
    });
    expect(fixture.requests.every((r) => r.method == 'GET'), isTrue);
    final areas = fixture.requests.firstWhere((r) => _table(r) == 'areas');
    expect(areas.headers['accept-profile'], 'public');
    expect(areas.url.queryParameters['select'], 'id,nombre');
    expect(structure.sortedAreas.map((area) => area.name), [
      'PRODUCTOS TECNOLÓGICOS',
      'SERVICIOS',
    ]);
    expect(structure.areaLeaders('PRODUCTOS TECNOLÓGICOS'), {
      'area@finnegans.com',
    });
    expect(structure.teamLeaders('PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE'), {
      'uno@finnegans.com',
      'dos@finnegans.com',
    });
  });

  test('Las faltantes crean primero las áreas y después sus equipos', () async {
    final fixture = _fixture((request) async {
      if (request.method == 'GET' && _table(request) == 'areas') {
        return _json(request, [
          {'id': 1, 'nombre': 'SERVICIOS'},
          {'id': 7, 'nombre': 'RRHH'},
        ]);
      }
      return _json(request, [], 201);
    });

    await fixture.repositorio.registerMissing(
      const PayrollGaps(
        areas: ['RRHH'],
        teams: [
          (area: 'rrhh', team: 'Selección'),
          (area: 'SERVICIOS', team: 'Soporte'),
        ],
      ),
    );

    expect(fixture.requests.map((r) => '${r.method} ${_table(r)}').toList(), [
      'POST areas',
      'GET areas',
      'POST equipos',
    ]);
    expect(jsonDecode(fixture.requests[0].body), [
      {'nombre': 'RRHH'},
    ]);
    expect(jsonDecode(fixture.requests[2].body), [
      {'area_id': 7, 'nombre': 'Selección'},
      {'area_id': 1, 'nombre': 'Soporte'},
    ]);
  });

  test('Sin faltantes no escribe nada', () async {
    final fixture = _fixture((request) async => _json(request, []));
    await fixture.repositorio.registerMissing(const PayrollGaps());
    expect(fixture.requests, isEmpty);
  });

  test('Asignar líderes aplica solo la diferencia', () async {
    final fixture = _fixture((request) async {
      if (request.method == 'GET') {
        return _json(request, [
          {'email': 'queda@finnegans.com'},
          {'email': 'sale@finnegans.com'},
        ]);
      }
      return _json(request, [], request.method == 'POST' ? 201 : 200);
    });

    await fixture.repositorio.assignTeamLeaders('10', {
      ' Queda@Finnegans.com',
      'entra@finnegans.com',
    });

    expect(fixture.requests.map((r) => '${r.method} ${_table(r)}').toList(), [
      'GET equipo_lideres',
      'DELETE equipo_lideres',
      'POST equipo_lideres',
    ]);
    expect(fixture.requests[0].url.queryParameters['equipo_id'], 'eq.10');
    expect(fixture.requests[1].url.queryParameters['equipo_id'], 'eq.10');
    expect(
      fixture.requests[1].url.queryParameters['email'],
      'in.("sale@finnegans.com")',
    );
    expect(jsonDecode(fixture.requests[2].body), [
      {'equipo_id': 10, 'email': 'entra@finnegans.com'},
    ]);
  });

  test('Sin cambios en los líderes solo lee', () async {
    final fixture = _fixture(
      (request) async => _json(request, [
        {'email': 'ana@finnegans.com'},
      ]),
    );
    await fixture.repositorio.assignLeadersArea('1', {'ana@finnegans.com'});
    expect(fixture.requests.single.method, 'GET');
    expect(_table(fixture.requests.single), 'area_lideres');
  });

  test('Los errores de PostgREST llegan como mensajes para mostrar', () async {
    final noPermission = _fixture((request) async => _error(request, '42501'));
    await expectLater(
      noPermission.repositorio.assignLeadersArea('1', {'ana@finnegans.com'}),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'No tenés permiso para cambiar áreas, equipos o líderes.',
        ),
      ),
    );
    await expectLater(
      noPermission.repositorio.getStructure(),
      throwsA(isA<FormatException>()),
    );

    final missingTables = _fixture((request) async => _error(request, '42P01'));
    await expectLater(
      missingTables.repositorio.getStructure(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('supabase/areas_equipos_rls.sql'),
        ),
      ),
    );
  });
}
