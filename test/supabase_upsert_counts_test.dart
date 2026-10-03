import 'dart:convert';

import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/data/supabase/supabase_mapping.dart';
import 'package:app_finnegans/data/supabase/supabase_repositories.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseTableMapping _mapping(
  String table,
  List<String> fields,
  List<String> keys,
) => SupabaseTableMapping(
  table: table,
  columns: {for (final field in fields) field: 'col_$field'},
  conflictFields: keys,
);

final _empleadosMapping = _mapping(
  'empleados',
  [
    'legajo',
    'mail',
    'nombre',
    'apellido',
    'seniority',
    'area',
    'equipo',
    'gerente',
    'fechaIngreso',
  ],
  ['legajo'],
);
final _cursosMapping = _mapping(
  'cursos',
  ['id', 'nombre', 'tipo', 'cargaHorariaHs'],
  ['id'],
);
final _horasMapping = _mapping(
  'horas_capacitacion',
  [
    'id',
    'empleadoLegajo',
    'cursoId',
    'fecha',
    'caso',
    'descripcionCurso',
    'clasificacion',
    'proyecto',
    'proyectoItem',
    'horasTotales',
    'descripcion',
  ],
  ['id'],
);
final _finalizacionesMapping = _mapping(
  'finalizaciones_cursos',
  ['legajo', 'cursoId', 'finalizoCurso', 'fechaFinalizacion'],
  ['legajo', 'cursoId'],
);

Curso _curso(String id) => Curso(
  id: id,
  nombre: 'Curso $id',
  tipo: TipoCurso.habilidadesDeNegocio,
  areaCurso: '',
  instructorLegajo: '',
  cargaHorariaHs: 2,
);
Empleado _empleado(String legajo, {String area = 'Sector A'}) => Empleado(
  legajo: legajo,
  nombre: 'Nombre',
  apellido: 'Apellido',
  seniority: Seniority.junior1,
  area: area,
  mail: 'empleado$legajo@example.com',
);
CargaDeHorasCRM _hora(String id, {double horas = 2}) => CargaDeHorasCRM(
  id: id,
  cursoNombre: 'Curso 1',
  empleadoLegajo: '10',
  fecha: DateTime(2025, 1, 1),
  horasTotales: horas,
  tipo: TipoCargaDeHoras.tomada,
);
CertificacionMoodle _finalizacion(
  String legajo,
  String cursoId, {
  bool finalizo = true,
}) => CertificacionMoodle(
  legajo: legajo,
  cursoNombre: 'Curso $cursoId',
  finalizoCurso: finalizo,
  fechaFinalizacion: finalizo ? DateTime(2025, 1, 1) : null,
);

class _Catalogo implements CursosRepository {
  @override
  Future<List<Curso>> getCursos({String? id, String? nombre}) async => [
    for (final courseId in ['1', '2'])
      if ((id == null || id == courseId) &&
          (nombre == null || nombre.trim().toLowerCase() == 'curso $courseId'))
        _curso(courseId),
  ];
  @override
  Future<void> replaceCursos(List<Curso> cursos) async =>
      throw UnsupportedError('No se escribe el catálogo de esta prueba.');
  @override
  Future<void> resetToMock() async {}
}

/// Persists rows in memory while honoring the key filters and pagination.
class _RemoteTable {
  final SupabaseTableMapping mapping;
  final requests = <http.Request>[];
  final rows = <String, Map<String, dynamic>>{};
  late final client = SupabaseClient(
    'https://test.supabase.co',
    'public-test-key',
    httpClient: MockClient(_handle),
  );
  _RemoteTable(this.mapping);

  List<String> get columns =>
      mapping.conflictFields.map(mapping.column).toList();
  String key(Map<String, dynamic> row) =>
      jsonEncode([for (final column in columns) row[column].toString()]);

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    expect(request.url.path, endsWith(mapping.table));
    if (request.method == 'POST') {
      final payload = (jsonDecode(request.body) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      expect(payload.map(key).toSet().length, payload.length);
      expect(request.url.queryParameters['on_conflict'], mapping.onConflict);
      for (final row in payload) {
        rows[key(row)] = row;
      }
      return http.Response('', 201, request: request);
    }
    expect(request.method, 'GET');
    final params = request.url.queryParameters;
    expect(params['select'], columns.join(','));
    var selected = rows.values.where((row) {
      if (columns.length == 1) {
        final filter = params[columns.single]!;
        expect(filter, startsWith('in.('));
        final keys =
            (jsonDecode('[${filter.substring(4, filter.length - 1)}]') as List)
                .map((value) => value.toString());
        return keys.contains(row[columns.single].toString());
      }
      final filter = params['or']!;
      final pair =
          'and(${columns.map((c) => '$c.eq.${jsonEncode(row[c])}').join(',')})';
      return filter.contains(pair);
    }).toList();
    final offset = int.parse(params['offset']!);
    final limit = int.parse(params['limit']!);
    selected = selected.skip(offset).take(limit).toList();
    return http.Response(
      jsonEncode([
        for (final row in selected)
          {for (final column in columns) column: row[column]},
      ]),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

void _expectCounts(
  ResultadoUpsert result,
  int processed,
  int inserted,
  int updated,
) {
  expect(result.registrosProcesados, processed);
  expect(result.insertados, inserted);
  expect(result.actualizados, updated);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Result sums known counts and preserves unknown counts', () {
    final result =
        const ResultadoUpsert(
          registrosProcesados: 3,
          insertados: 1,
          actualizados: 2,
        ) +
        const ResultadoUpsert(
          registrosProcesados: 2,
          insertados: 1,
          actualizados: 1,
        );
    _expectCounts(result, 5, 2, 3);
    final unknown = result + const ResultadoUpsert(registrosProcesados: 4);
    expect(unknown.registrosProcesados, 9);
    expect(unknown.insertados, isNull);
    expect(unknown.actualizados, isNull);
    _expectCounts(ResultadoUpsert.empty, 0, 0, 0);
  });

  test(
    'Employees count first import and identical reimport without duplicate keys',
    () async {
      final remote = _RemoteTable(_empleadosMapping);
      addTearDown(remote.client.dispose);
      final EmpleadosRepository repo = SupabaseEmpleadosRepository(
        remote.client,
        remote.mapping,
      );
      final batch = [
        _empleado('10'),
        _empleado('20'),
        _empleado('10', area: 'Sector B'),
      ];
      _expectCounts(await repo.upsertEmpleadosConResultado(batch), 3, 2, 0);
      _expectCounts(await repo.upsertEmpleadosConResultado(batch), 3, 0, 2);
      expect(remote.rows.length, 2);
      expect(
        remote.rows.values.singleWhere(
          (r) => r['col_legajo'] == '10',
        )['col_area'],
        'Sector B',
      );
      expect(remote.rows.values.every((r) => !r.containsKey('activo')), isTrue);
      final writes = remote.requests.where((r) => r.method == 'POST').toList();
      expect(writes.last.body, writes.first.body);
      expect(remote.requests.where((r) => r.method == 'GET').length, 2);
    },
  );

  test(
    'Courses count first import and identical reimport without duplicate keys',
    () async {
      final remote = _RemoteTable(_cursosMapping);
      addTearDown(remote.client.dispose);
      final CursosRepository repo = SupabaseCursosRepository(
        remote.client,
        remote.mapping,
      );
      final batch = [_curso('1'), _curso('2'), _curso('1')];
      _expectCounts(await repo.upsertCursosConResultado(batch), 3, 2, 0);
      _expectCounts(await repo.upsertCursosConResultado(batch), 3, 0, 2);
      expect(remote.rows.length, 2);
      expect(remote.requests.where((r) => r.method == 'GET').length, 2);
    },
  );

  test(
    'CRM transactions count first import and identical reimport without duplicate keys',
    () async {
      final remote = _RemoteTable(_horasMapping);
      addTearDown(remote.client.dispose);
      final CargaDeHorasCRMRepository repo = SupabaseCargaDeHorasCRMRepository(
        remote.client,
        remote.mapping,
        _Catalogo(),
      );
      final batch = [_hora('txn1'), _hora('txn2'), _hora('txn1', horas: 4)];
      _expectCounts(await repo.upsertCargasDeHorasConResultado(batch), 3, 2, 0);
      _expectCounts(await repo.upsertCargasDeHorasConResultado(batch), 3, 0, 2);
      expect(remote.rows.length, 2);
      expect(
        remote.rows.values.singleWhere(
          (r) => r['col_id'] == 'txn1',
        )['col_horasTotales'],
        4,
      );
      expect(remote.requests.where((r) => r.method == 'GET').length, 2);
    },
  );

  test(
    'Completions count first import and identical reimport by composite key',
    () async {
      final remote = _RemoteTable(_finalizacionesMapping);
      addTearDown(remote.client.dispose);
      final CertificacionesMoodleRepository repo =
          SupabaseCertificacionesMoodleRepository(
            remote.client,
            remote.mapping,
            _Catalogo(),
          );
      final batch = [
        _finalizacion('10', '1'),
        _finalizacion('10', '2'),
        _finalizacion('10', '1', finalizo: false),
      ];
      _expectCounts(
        await repo.upsertCertificacionesConResultado(batch),
        3,
        2,
        0,
      );
      _expectCounts(
        await repo.upsertCertificacionesConResultado(batch),
        3,
        0,
        2,
      );
      expect(remote.rows.length, 2);
      expect(
        remote.rows.values.singleWhere(
          (r) => r['col_cursoId'] == '1',
        )['col_finalizoCurso'],
        false,
      );
      final get = remote.requests.first;
      expect(
        get.url.queryParameters['or'],
        '(and(col_legajo.eq."10",col_cursoId.eq."1"),and(col_legajo.eq."10",col_cursoId.eq."2"))',
      );
      expect(remote.requests.where((r) => r.method == 'GET').length, 2);
    },
  );

  test('Composite counts exclude crossed employee/course pairs', () async {
    final remote = _RemoteTable(_finalizacionesMapping);
    addTearDown(remote.client.dispose);
    for (final pair in [('10', '2'), ('20', '1'), ('10', '1')]) {
      final row = {'col_legajo': pair.$1, 'col_cursoId': pair.$2};
      remote.rows[remote.key(row)] = row;
    }
    final repo = SupabaseCertificacionesMoodleRepository(
      remote.client,
      remote.mapping,
      _Catalogo(),
    );
    _expectCounts(
      await repo.upsertCertificacionesConResultado([
        _finalizacion('10', '1'),
        _finalizacion('20', '2'),
      ]),
      2,
      1,
      1,
    );
    expect(
      remote.requests.first.url.queryParameters['or'],
      '(and(col_legajo.eq."10",col_cursoId.eq."1"),and(col_legajo.eq."20",col_cursoId.eq."2"))',
    );
    expect(remote.rows.length, 4);
  });

  test(
    'Composite filters escape punctuation, quotes and backslashes in values',
    () async {
      final remote = _RemoteTable(_finalizacionesMapping);
      addTearDown(remote.client.dispose);
      const legajo = '10,"(x)\\';
      final repo = SupabaseCertificacionesMoodleRepository(
        remote.client,
        remote.mapping,
        _Catalogo(),
      );
      _expectCounts(
        await repo.upsertCertificacionesConResultado([
          _finalizacion(legajo, '1'),
        ]),
        1,
        1,
        0,
      );
      expect(
        remote.requests.first.url.queryParameters['or'],
        '(and(col_legajo.eq.${jsonEncode(legajo)},col_cursoId.eq."1"))',
      );
      _expectCounts(
        await repo.upsertCertificacionesConResultado([
          _finalizacion(legajo, '1'),
        ]),
        1,
        0,
        1,
      );
    },
  );

  test(
    'Key reads use bounded batches and page existing keys, never full models',
    () async {
      final remote = _RemoteTable(_cursosMapping);
      addTearDown(remote.client.dispose);
      final batch = List.generate(321, (i) => _curso('$i'));
      for (final curso in batch.take(160)) {
        final row = {'col_id': curso.id};
        remote.rows[remote.key(row)] = row;
      }
      final repo = SupabaseCursosRepository(remote.client, remote.mapping);
      _expectCounts(await repo.upsertCursosConResultado(batch), 321, 161, 160);
      final gets = remote.requests.where((r) => r.method == 'GET').toList();
      expect(gets.length, 4); // 3 batches; first batch needs 2 pages.
      expect(gets.any((r) => r.url.queryParameters['offset'] == '100'), isTrue);
      for (final request in gets) {
        final params = request.url.queryParameters;
        expect(params['select'], 'col_id');
        final filter = params['col_id']!;
        expect(filter, startsWith('in.('));
        expect(
          filter.substring(4, filter.length - 1).split(',').length,
          lessThanOrEqualTo(150),
        );
      }
      expect(remote.requests.where((r) => r.method == 'POST').length, 1);
    },
  );

  test('Numeric database IDs match their Dart string keys', () async {
    final client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          request.method == 'GET' ? '[{"col_id":7}]' : '',
          request.method == 'GET' ? 200 : 201,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    _expectCounts(
      await SupabaseCursosRepository(
        client,
        _cursosMapping,
      ).upsertCursosConResultado([_curso('7')]),
      1,
      0,
      1,
    );
  });

  for (final failingMethod in ['GET', 'POST']) {
    test(
      '$failingMethod failure propagates with no successful counted result or local fallback',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-test-key',
          httpClient: MockClient((request) async {
            requests.add(request);
            final failure = request.method == failingMethod;
            return http.Response(
              failure ? '{"message":"denied","code":"42501"}' : '[]',
              failure ? 403 : 200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await expectLater(
          SupabaseCursosRepository(
            client,
            _cursosMapping,
          ).upsertCursosConResultado([_curso('1')]),
          throwsA(isA<PostgrestException>()),
        );
        expect(requests.length, failingMethod == 'GET' ? 1 : 2);
        expect(
          (await SharedPreferences.getInstance()).containsKey(
            'formacion_cursos',
          ),
          isFalse,
        );
      },
    );
  }

  test(
    'Empty counted batches return zero and make no network requests',
    () async {
      final remote = _RemoteTable(_cursosMapping);
      addTearDown(remote.client.dispose);
      _expectCounts(
        await SupabaseEmpleadosRepository(
          remote.client,
          _empleadosMapping,
        ).upsertEmpleadosConResultado([]),
        0,
        0,
        0,
      );
      _expectCounts(
        await SupabaseCursosRepository(
          remote.client,
          _cursosMapping,
        ).upsertCursosConResultado([]),
        0,
        0,
        0,
      );
      _expectCounts(
        await SupabaseCargaDeHorasCRMRepository(
          remote.client,
          _horasMapping,
          _Catalogo(),
        ).upsertCargasDeHorasConResultado([]),
        0,
        0,
        0,
      );
      _expectCounts(
        await SupabaseCertificacionesMoodleRepository(
          remote.client,
          _finalizacionesMapping,
          _Catalogo(),
        ).upsertCertificacionesConResultado([]),
        0,
        0,
        0,
      );
      expect(remote.requests, isEmpty);
    },
  );

  test(
    'Local fallback persists through existing methods and leaves counts unknown',
    () async {
      final employees = LocalEmpleadosRepository();
      final courses = LocalCursosRepository();
      final hours = LocalCargaDeHorasCRMRepository();
      final completions = LocalCertificacionesMoodleRepository();
      final results = [
        await employees.upsertEmpleadosConResultado([_empleado('10')]),
        await courses.upsertCursosConResultado([_curso('1')]),
        await hours.upsertCargasDeHorasConResultado([_hora('txn1')]),
        await completions.upsertCertificacionesConResultado([
          _finalizacion('10', '1'),
        ]),
      ];
      for (final result in results) {
        expect(result.registrosProcesados, 1);
        expect(result.insertados, isNull);
        expect(result.actualizados, isNull);
      }
      expect((await employees.getEmpleados()).single.legajo, '10');
      expect((await courses.getCursos()).single.id, '1');
      expect((await hours.getCargasDeHoras()).single.id, 'txn1');
      expect((await completions.getCertificaciones()).single.legajo, '10');
    },
  );
}
