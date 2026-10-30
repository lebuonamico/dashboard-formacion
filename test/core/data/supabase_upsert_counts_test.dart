import 'dart:convert';

import 'package:app_finnegans/core/legacy/local_repositories.dart';
import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/core/data/supabase_repositories.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
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

final _employeesMapping = _mapping(
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
final _coursesMapping = _mapping(
  'cursos',
  ['id', 'nombre', 'clasificacion', 'cargaHorariaHs'],
  ['id'],
);
final _hoursMapping = _mapping(
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
final _completionsMapping = _mapping(
  'finalizaciones_cursos',
  ['legajo', 'cursoId', 'finalizoCurso', 'fechaFinalizacion'],
  ['legajo', 'cursoId'],
);

Course _course(String id) => Course(
  id: id,
  name: 'Curso $id',
  category: CourseCategory.businessSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 2,
);
Employee _employee(String employeeId, {String area = 'Sector A'}) => Employee(
  employeeId: employeeId,
  firstName: 'Nombre',
  lastName: 'Apellido',
  seniority: Seniority.junior1,
  area: area,
  email: 'empleado$employeeId@example.com',
);
CrmTimeEntry _hour(String id, {double hours = 2}) => CrmTimeEntry(
  id: id,
  courseName: 'Curso 1',
  employeeId: '10',
  date: DateTime(2025, 1, 1),
  hours: hours,
  kind: TimeEntryKind.taken,
);
LmsCertification _completion(
  String employeeId,
  String courseId, {
  bool completed = true,
}) => LmsCertification(
  employeeId: employeeId,
  courseName: 'Curso $courseId',
  isCompleted: completed,
  completedAt: completed ? DateTime(2025, 1, 1) : null,
);

class _Catalog implements CoursesRepository {
  @override
  Future<List<Course>> getCourses({String? id, String? name}) async => [
    for (final courseId in ['1', '2'])
      if ((id == null || id == courseId) &&
          (name == null || name.trim().toLowerCase() == 'curso $courseId'))
        _course(courseId),
  ];
  @override
  Future<void> replaceCourses(List<Course> courses) async =>
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
  UpsertResult result,
  int processed,
  int inserted,
  int updated,
) {
  expect(result.processedRecords, processed);
  expect(result.inserted, inserted);
  expect(result.updated, updated);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Result sums known counts and preserves unknown counts', () {
    final result =
        const UpsertResult(processedRecords: 3, inserted: 1, updated: 2) +
        const UpsertResult(processedRecords: 2, inserted: 1, updated: 1);
    _expectCounts(result, 5, 2, 3);
    final unknown = result + const UpsertResult(processedRecords: 4);
    expect(unknown.processedRecords, 9);
    expect(unknown.inserted, isNull);
    expect(unknown.updated, isNull);
    _expectCounts(UpsertResult.empty, 0, 0, 0);
  });

  test(
    'Employees count first import and identical reimport without duplicate keys',
    () async {
      final remote = _RemoteTable(_employeesMapping);
      addTearDown(remote.client.dispose);
      final EmployeesRepository repo = SupabaseEmployeesRepository(
        remote.client,
        remote.mapping,
      );
      final batch = [
        _employee('10'),
        _employee('20'),
        _employee('10', area: 'Sector B'),
      ];
      _expectCounts(await repo.upsertEmployeesWithResult(batch), 3, 2, 0);
      _expectCounts(await repo.upsertEmployeesWithResult(batch), 3, 0, 2);
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
      final remote = _RemoteTable(_coursesMapping);
      addTearDown(remote.client.dispose);
      final CoursesRepository repo = SupabaseCoursesRepository(
        remote.client,
        remote.mapping,
      );
      final batch = [_course('1'), _course('2'), _course('1')];
      _expectCounts(await repo.upsertCoursesWithResult(batch), 3, 2, 0);
      _expectCounts(await repo.upsertCoursesWithResult(batch), 3, 0, 2);
      expect(remote.rows.length, 2);
      expect(remote.requests.where((r) => r.method == 'GET').length, 2);
    },
  );

  test(
    'CRM transactions count first import and identical reimport without duplicate keys',
    () async {
      final remote = _RemoteTable(_hoursMapping);
      addTearDown(remote.client.dispose);
      final CrmTimeEntriesRepository repo = SupabaseCrmTimeEntriesRepository(
        remote.client,
        remote.mapping,
        _Catalog(),
      );
      final batch = [_hour('txn1'), _hour('txn2'), _hour('txn1', hours: 4)];
      _expectCounts(await repo.upsertTimeEntriesWithResult(batch), 3, 2, 0);
      _expectCounts(await repo.upsertTimeEntriesWithResult(batch), 3, 0, 2);
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
      final remote = _RemoteTable(_completionsMapping);
      addTearDown(remote.client.dispose);
      final LmsCertificationsRepository repo =
          SupabaseLmsCertificationsRepository(
            remote.client,
            remote.mapping,
            _Catalog(),
          );
      final batch = [
        _completion('10', '1'),
        _completion('10', '2'),
        _completion('10', '1', completed: false),
      ];
      _expectCounts(await repo.upsertCertificationsWithResult(batch), 3, 2, 0);
      _expectCounts(await repo.upsertCertificationsWithResult(batch), 3, 0, 2);
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
    final remote = _RemoteTable(_completionsMapping);
    addTearDown(remote.client.dispose);
    for (final pair in [('10', '2'), ('20', '1'), ('10', '1')]) {
      final row = {'col_legajo': pair.$1, 'col_cursoId': pair.$2};
      remote.rows[remote.key(row)] = row;
    }
    final repo = SupabaseLmsCertificationsRepository(
      remote.client,
      remote.mapping,
      _Catalog(),
    );
    _expectCounts(
      await repo.upsertCertificationsWithResult([
        _completion('10', '1'),
        _completion('20', '2'),
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
      final remote = _RemoteTable(_completionsMapping);
      addTearDown(remote.client.dispose);
      const employeeId = '10,"(x)\\';
      final repo = SupabaseLmsCertificationsRepository(
        remote.client,
        remote.mapping,
        _Catalog(),
      );
      _expectCounts(
        await repo.upsertCertificationsWithResult([
          _completion(employeeId, '1'),
        ]),
        1,
        1,
        0,
      );
      expect(
        remote.requests.first.url.queryParameters['or'],
        '(and(col_legajo.eq.${jsonEncode(employeeId)},col_cursoId.eq."1"))',
      );
      _expectCounts(
        await repo.upsertCertificationsWithResult([
          _completion(employeeId, '1'),
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
      final remote = _RemoteTable(_coursesMapping);
      addTearDown(remote.client.dispose);
      final batch = List.generate(321, (i) => _course('$i'));
      for (final course in batch.take(160)) {
        final row = {'col_id': course.id};
        remote.rows[remote.key(row)] = row;
      }
      final repo = SupabaseCoursesRepository(remote.client, remote.mapping);
      _expectCounts(await repo.upsertCoursesWithResult(batch), 321, 161, 160);
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
      await SupabaseCoursesRepository(
        client,
        _coursesMapping,
      ).upsertCoursesWithResult([_course('7')]),
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
          SupabaseCoursesRepository(
            client,
            _coursesMapping,
          ).upsertCoursesWithResult([_course('1')]),
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
      final remote = _RemoteTable(_coursesMapping);
      addTearDown(remote.client.dispose);
      _expectCounts(
        await SupabaseEmployeesRepository(
          remote.client,
          _employeesMapping,
        ).upsertEmployeesWithResult([]),
        0,
        0,
        0,
      );
      _expectCounts(
        await SupabaseCoursesRepository(
          remote.client,
          _coursesMapping,
        ).upsertCoursesWithResult([]),
        0,
        0,
        0,
      );
      _expectCounts(
        await SupabaseCrmTimeEntriesRepository(
          remote.client,
          _hoursMapping,
          _Catalog(),
        ).upsertTimeEntriesWithResult([]),
        0,
        0,
        0,
      );
      _expectCounts(
        await SupabaseLmsCertificationsRepository(
          remote.client,
          _completionsMapping,
          _Catalog(),
        ).upsertCertificationsWithResult([]),
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
      final employees = LocalEmployeesRepository();
      final courses = LocalCoursesRepository();
      final hours = LocalCrmTimeEntriesRepository();
      final completions = LocalLmsCertificationsRepository();
      final results = [
        await employees.upsertEmployeesWithResult([_employee('10')]),
        await courses.upsertCoursesWithResult([_course('1')]),
        await hours.upsertTimeEntriesWithResult([_hour('txn1')]),
        await completions.upsertCertificationsWithResult([
          _completion('10', '1'),
        ]),
      ];
      for (final result in results) {
        expect(result.processedRecords, 1);
        expect(result.inserted, isNull);
        expect(result.updated, isNull);
      }
      expect((await employees.getEmployees()).single.employeeId, '10');
      expect((await courses.getCourses()).single.id, '1');
      expect((await hours.getTimeEntries()).single.id, 'txn1');
      expect((await completions.getCertifications()).single.employeeId, '10');
    },
  );
}
