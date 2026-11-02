import 'dart:convert';

import 'package:app_finnegans/features/org_structure/data/supabase_org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
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

final _now = DateTime.utc(2026, 9, 14, 13);

String _table(http.Request request) =>
    request.url.path.replaceFirst('/rest/v1/', '');

/// Los emails del filtro `email=in.(...)` de un pedido.
List<String> _emailsIn(http.Request request) => RegExp(r'"([^"]*)"')
    .allMatches(request.url.queryParameters['email'] ?? '')
    .map((match) => match.group(1)!)
    .toList();

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
    const service = OrgStructureService();

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
    expect(service.sortedAreas(structure).map((area) => area.name), [
      'PRODUCTOS TECNOLÓGICOS',
      'SERVICIOS',
    ]);
    expect(service.areaLeaders(structure, 'PRODUCTOS TECNOLÓGICOS'), {
      'area@finnegans.com',
    });
    expect(
      service.teamLeaders(
        structure,
        'PRODUCTOS TECNOLÓGICOS',
        'PLATAFORMA CORE',
      ),
      {'uno@finnegans.com', 'dos@finnegans.com'},
    );
  });

  test('Normaliza los emails de los líderes al leer', () async {
    final fixture = _fixture((request) async {
      return switch (_table(request)) {
        'areas' => _json(request, [
          {'id': 1, 'nombre': 'SERVICIOS'},
        ]),
        'equipos' => _json(request, []),
        'area_lideres' => _json(request, [
          {'area_id': 1, 'email': ' Area@Finnegans.COM '},
          {'area_id': 1, 'email': ''},
        ]),
        'equipo_lideres' => _json(request, []),
        _ => throw StateError('Request inesperado: ${request.url}'),
      };
    });

    final structure = await fixture.repositorio.getStructure();

    expect(structure.areas.single.leaders, {'area@finnegans.com'});
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

  test('Asignar líderes da de baja, reactiva y agrega sin borrar', () async {
    final fixture = _fixture((request) async {
      return switch (request.method) {
        'GET' => _json(request, [
          {'email': 'queda@finnegans.com', 'ff_baja': null},
          {'email': 'sale@finnegans.com', 'ff_baja': null},
          {'email': 'vuelve@finnegans.com', 'ff_baja': '2026-08-01T00:00:00Z'},
          {'email': 'sigue@finnegans.com', 'ff_baja': '2026-08-01T00:00:00Z'},
        ]),
        'PATCH' => _json(request, [
          for (final email in _emailsIn(request)) {'email': email},
        ]),
        _ => _json(request, [], 201),
      };
    });

    await fixture.repositorio.assignTeamLeaders('10', {
      ' Queda@Finnegans.com',
      'vuelve@finnegans.com',
      'entra@finnegans.com',
    }, now: _now);

    expect(fixture.requests.map((r) => '${r.method} ${_table(r)}').toList(), [
      'GET equipo_lideres',
      'PATCH equipo_lideres',
      'PATCH equipo_lideres',
      'POST equipo_lideres',
    ]);
    final [read, end, reactivate, add] = fixture.requests;
    expect(read.url.queryParameters, {
      'select': 'email,ff_baja',
      'equipo_id': 'eq.10',
    });
    expect(end.url.queryParameters, {
      'equipo_id': 'eq.10',
      'ff_baja': 'is.null',
      'email': 'in.("sale@finnegans.com")',
      'select': 'email',
    });
    expect(jsonDecode(end.body), {'ff_baja': '2026-09-14T13:00:00.000Z'});
    expect(reactivate.url.queryParameters, {
      'equipo_id': 'eq.10',
      'email': 'in.("vuelve@finnegans.com")',
      'select': 'email',
    });
    expect(jsonDecode(reactivate.body), {'ff_baja': null});
    expect(jsonDecode(add.body), [
      {
        'equipo_id': 10,
        'email': 'entra@finnegans.com',
        'ff_alta': '2026-09-14T13:00:00.000Z',
      },
    ]);
  });

  test('La estructura solo trae los líderes vigentes', () async {
    final fixture = _fixture((request) async => _json(request, []));

    await fixture.repositorio.getStructure();

    for (final table in ['area_lideres', 'equipo_lideres']) {
      final request = fixture.requests.singleWhere((r) => _table(r) == table);
      expect(request.url.queryParameters['ff_baja'], 'is.null');
    }
    final areas = fixture.requests.singleWhere((r) => _table(r) == 'areas');
    expect(areas.url.queryParameters.containsKey('ff_baja'), isFalse);
  });

  test('La baja filtra por el email tal como está guardado', () async {
    final fixture = _fixture((request) async {
      return switch (request.method) {
        'GET' => _json(request, [
          {'email': 'Sale@Finnegans.com', 'ff_baja': null},
        ]),
        _ => _json(request, [
          {'email': 'Sale@Finnegans.com'},
        ]),
      };
    });

    await fixture.repositorio.assignAreaLeaders('1', const {}, now: _now);

    expect(
      fixture.requests.last.url.queryParameters['email'],
      'in.("Sale@Finnegans.com")',
    );
  });

  test('Una baja que no actualiza ninguna fila es un error', () async {
    final fixture = _fixture((request) async {
      return switch (request.method) {
        'GET' => _json(request, [
          {'email': 'ana@finnegans.com', 'ff_baja': null},
        ]),
        _ => _json(request, []),
      };
    });

    await expectLater(
      fixture.repositorio.assignAreaLeaders('1', const {}, now: _now),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Recargá la pantalla'),
        ),
      ),
    );
  });

  test('Sin cambios en los líderes solo lee', () async {
    final fixture = _fixture(
      (request) async => _json(request, [
        {'email': 'ana@finnegans.com', 'ff_baja': null},
        {'email': 'beto@finnegans.com', 'ff_baja': '2026-08-01T00:00:00Z'},
      ]),
    );
    await fixture.repositorio.assignAreaLeaders('1', {
      'ana@finnegans.com',
    }, now: _now);
    expect(fixture.requests.single.method, 'GET');
    expect(_table(fixture.requests.single), 'area_lideres');
  });

  test('Los errores de PostgREST llegan como mensajes para mostrar', () async {
    final noPermission = _fixture((request) async => _error(request, '42501'));
    await expectLater(
      noPermission.repositorio.assignAreaLeaders('1', {
        'ana@finnegans.com',
      }, now: _now),
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

    final missingColumns = _fixture(
      (request) async => _error(request, '42703'),
    );
    await expectLater(
      missingColumns.repositorio.getStructure(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('supabase/lideres_baja_logica.sql'),
        ),
      ),
    );
  });
}
