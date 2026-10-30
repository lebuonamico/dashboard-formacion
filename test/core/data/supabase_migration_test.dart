import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/core/legacy/local_repositories.dart';
import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/core/data/supabase_repositories.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';

Course course({String id = '107', String name = 'Curso LMS'}) => Course(
  id: id,
  name: name,
  category: CourseCategory.businessSkills,
  courseArea: 'Solo local',
  instructorEmployeeId: 'Solo local',
  workloadHours: 4,
);

SupabaseTableMapping mapping(
  String table,
  List<String> fields,
  List<String> conflicts,
) => SupabaseTableMapping(
  table: table,
  columns: {for (final f in fields) f: 'col_$f'},
  conflictFields: conflicts,
);

final courseMapping = mapping(
  'test_catalog',
  ['id', 'nombre', 'clasificacion', 'cargaHorariaHs'],
  ['id'],
);
final hoursMapping = mapping(
  'test_hours',
  [
    'id',
    'empleadoLegajo',
    'cursoId',
    'fecha',
    'horasTotales',
    'caso',
    'descripcionCurso',
    'clasificacion',
    'proyecto',
    'proyectoItem',
    'descripcion',
  ],
  ['id'],
);
final completionMapping = mapping(
  'test_completion',
  ['legajo', 'cursoId', 'finalizoCurso', 'fechaFinalizacion'],
  ['legajo', 'cursoId'],
);

/// Respuesta de PostgREST con el total en `content-range`, como la manda
/// Supabase cuando se pide el conteo.
http.Response _rows(
  http.BaseRequest request,
  List<Map<String, dynamic>> rows, {
  int? total,
}) {
  final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
  final range = rows.isEmpty ? '*' : '$offset-${offset + rows.length - 1}';
  return http.Response(
    jsonEncode(rows),
    200,
    request: request,
    headers: {
      'content-type': 'application/json',
      'content-range': '$range/${total ?? rows.length}',
    },
  );
}

class Audit implements ImportRecordsRepository {
  final records = <ImportRecord>[];
  @override
  Future<void> register(ImportRecord record) async {
    records.add(record);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Course matching trims/cases, rejects ambiguity and never interprets Caso as ID',
    () {
      expect(courseResolver('  CURSO lms ', [course()]).id, '107');
      expect(
        () => courseResolver('Choras - 107', [course()]),
        throwsFormatException,
      );
      expect(
        () => courseResolver('Curso', [course(name: 'Curso LMS')]),
        throwsFormatException,
      );
      expect(
        () => courseResolver('Curso LMS', [course(), course(id: '2')]),
        throwsFormatException,
      );
    },
  );

  test('Historical dates reject missing, invalid and overflow values', () {
    for (final value in [
      '',
      'incorrecto',
      '31/02/2025',
      '2025-02-31',
      '2025-13-01',
      '2025-01-01T25:00:00',
      'Infinity',
      '0',
    ]) {
      expect(() => requiredDate(value), throwsFormatException, reason: value);
    }
    expect(requiredDate('15/09/2025'), DateTime(2025, 9, 15));
    expect(requiredDate('2025-09-15'), DateTime(2025, 9, 15));
    expect(requiredDate('45915'), DateTime(2025, 9, 15));
    expect(
      requiredDate('2025-01-01T00:00:00+03:00'),
      DateTime.utc(2024, 12, 31, 21),
    );
    expect(
      () => CrmTimeEntry.fromJson({'fecha': 'invalid'}),
      throwsFormatException,
    );
    expect(
      () => LmsCertification.fromJson({'fechaFinalizacion': '2025-02-31'}),
      throwsFormatException,
    );
  });

  test('Local fallback reads mocks without recursion', () async {
    expect(await LocalEmployeesRepository().getEmployees(), isNotEmpty);
    expect(await LocalCoursesRepository().getCourses(), isNotEmpty);
    expect(await LocalCrmTimeEntriesRepository().getTimeEntries(), isNotEmpty);
    expect(
      await LocalLmsCertificationsRepository().getCertifications(),
      isEmpty,
    );
  });

  test(
    'Local UPSERT preserves old CRM data and updates same transaction',
    () async {
      final repo = LocalCrmTimeEntriesRepository();
      CrmTimeEntry item(String id, int month, double hours) => CrmTimeEntry(
        id: id,
        courseName: 'Curso LMS',
        courseId: '107',
        employeeId: '10',
        date: DateTime(2025, month, 1),
        hours: hours,
        kind: TimeEntryKind.taken,
      );
      await repo.replaceTimeEntries([item('old', 1, 2)]);
      await repo.upsertTimeEntries([item('new', 2, 3)]);
      await repo.upsertTimeEntries([item('new', 2, 4)]);
      final all = await repo.getTimeEntries();
      expect(all.length, 2);
      expect(all.singleWhere((i) => i.id == 'old').hours, 2);
      expect(all.singleWhere((i) => i.id == 'new').hours, 4);
      expect(
        (await repo.getTimeEntries(
          from: DateTime(2025, 2),
          until: DateTime(2025, 3),
        )).length,
        1,
      );
    },
  );

  test(
    'First local imports persist only imported records, retaining mocks as fallback',
    () async {
      final repo = LocalCoursesRepository();
      await repo.upsertCourses([course()]);
      expect((await repo.getCourses()).map((c) => c.id), ['107']);
      await repo.resetToMock();
      expect(await repo.getCourses(), isNotEmpty);
    },
  );

  test(
    'Local completions keep one row per employee/course and repeated import is idempotent',
    () async {
      final repo = LocalLmsCertificationsRepository();
      final january = LmsCertification(
        employeeId: '10',
        courseName: 'Curso LMS',
        isCompleted: true,
        completedAt: DateTime(2025, 1, 1),
      );
      final february = LmsCertification(
        employeeId: '10',
        courseName: 'Curso LMS',
        isCompleted: true,
        completedAt: DateTime(2025, 2, 1),
      );
      await repo.upsertCertifications([january]);
      await repo.upsertCertifications([february]);
      await repo.upsertCertifications([february]);
      final rows = await repo.getCertifications();
      expect(rows.length, 1);
      expect(rows.single.completedAt, DateTime(2025, 2, 1));
    },
  );

  test('Remote paging reads every page, the rest in parallel, even when the '
      'server caps pages below the requested size', () async {
    const total = 1001;
    const cap = 500;
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final offset = int.parse(request.url.queryParameters['offset']!);
        final limit = int.parse(request.url.queryParameters['limit']!);
        final count = [limit, cap, total - offset].reduce(min);
        return _rows(request, [
          for (var i = 0; i < count; i++)
            courseMapping.encode(course(id: '${offset + i}').toJson()),
        ], total: total);
      }),
    );
    final courses = await SupabaseCoursesRepository(
      client,
      courseMapping,
    ).getCourses();
    expect(courses.length, total);
    expect(courses.map((c) => c.id).toSet().length, total);
    expect(requests.map((r) => r.url.queryParameters['offset']), [
      '0',
      '500',
      '1000',
    ]);
    // Solo la primera página pide el total.
    expect(requests.first.headers['prefer'], contains('count=exact'));
    expect(requests.last.headers['prefer'] ?? '', isNot(contains('count')));
    await client.dispose();
  });

  test('Malformed locally stored historical dates are reported', () async {
    SharedPreferences.setMockInitialValues({
      'formacion_carga_de_horas_crm': '[{"fecha":"invalid"}]',
    });
    await expectLater(
      LocalCrmTimeEntriesRepository().getTimeEntries(),
      throwsFormatException,
    );
  });

  test('Physical mappings are explicit and exclude non-contract fields', () {
    expect(
      () => SupabaseTableMapping(table: '', columns: {}, conflictFields: []),
      throwsArgumentError,
    );
    expect(() => courseMapping.column('areaCurso'), throwsStateError);
    expect(
      courseMapping.encode(course().toJson()).keys,
      unorderedEquals([
        'col_id',
        'col_nombre',
        'col_clasificacion',
        'col_cargaHorariaHs',
      ]),
    );
  });

  test(
    'Supabase filters are sent to PostgREST and HTTP errors propagate',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return _rows(request, []);
        }),
      );
      final courses = SupabaseCoursesRepository(client, courseMapping);
      final hours = SupabaseCrmTimeEntriesRepository(
        client,
        hoursMapping,
        courses,
      );
      await hours.getTimeEntries(
        employeeId: '10',
        courseId: '107',
        from: DateTime(2025, 1),
        until: DateTime(2025, 2),
      );
      final params = requests.single.url.queryParametersAll;
      expect(params['col_empleadoLegajo'], ['eq.10']);
      expect(params['col_cursoId'], ['eq.107']);
      expect(
        params['col_fecha'],
        containsAll([
          'gte.2025-01-01T00:00:00.000',
          'lt.2025-02-01T00:00:00.000',
        ]),
      );
      // El catálogo se lee una vez; los filtros por nombre o ID se
      // resuelven sobre esa lectura.
      final before = requests.length;
      await courses.getCourses(name: '  A_100%  ');
      await courses.getCourses(id: '107');
      await courses.getCourses();
      expect(requests.length, before + 1);
      final denied = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"message":"denied","code":"42501"}',
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        SupabaseCoursesRepository(denied, courseMapping).getCourses(),
        throwsA(isA<PostgrestException>()),
      );
      await client.dispose();
      await denied.dispose();
    },
  );

  test(
    'Supabase UPSERT resolves FK by catalog name and retains CRM source fields',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return _rows(request, [courseMapping.encode(course().toJson())]);
          }
          return http.Response('', 201, request: request);
        }),
      );
      final courses = SupabaseCoursesRepository(client, courseMapping);
      final hours = SupabaseCrmTimeEntriesRepository(
        client,
        hoursMapping,
        courses,
      );
      await hours.replaceTimeEntries([
        CrmTimeEntry(
          id: 'txn',
          courseName: ' CURSO LMS ',
          courseId: 'wrong-source-id',
          employeeId: '10',
          date: DateTime(2025, 1, 1),
          hours: 2,
          kind: TimeEntryKind.taken,
          caseRef: 'Choras - 90',
          classification: 'CRM original',
          courseDescription: 'Descripción',
          project: 'P',
          projectItem: 'I',
          description: 'D',
        ),
      ]);
      final post = requests.last;
      expect(post.method, 'POST');
      expect(post.url.queryParameters['on_conflict'], 'col_id');
      expect(post.headers['prefer'], contains('resolution=merge-duplicates'));
      final row = (jsonDecode(post.body) as List).single as Map;
      expect(row['col_cursoId'], '107');
      expect(row['col_caso'], 'Choras - 90');
      expect(row['col_clasificacion'], 'CRM original');
      expect(row.keys, isNot(contains('tipo')));
      expect(requests.any((r) => r.method == 'DELETE'), isFalse);
      await courses.upsertCourses([course()]);
      final courseRow = (jsonDecode(requests.last.body) as List).single as Map;
      expect(
        courseRow.keys,
        unorderedEquals([
          'col_id',
          'col_nombre',
          'col_clasificacion',
          'col_cargaHorariaHs',
        ]),
      );
      await client.dispose();
    },
  );

  test(
    'Remote reads hydrate course names from FK without changing ViewModels',
    () async {
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          final row = request.url.path.endsWith('test_completion')
              ? completionMapping.encode({
                  'legajo': '10',
                  'cursoId': '107',
                  'finalizoCurso': true,
                  'fechaFinalizacion': '2025-01-15',
                })
              : courseMapping.encode(course().toJson());
          return _rows(request, [row]);
        }),
      );
      final repo = SupabaseLmsCertificationsRepository(
        client,
        completionMapping,
        SupabaseCoursesRepository(client, courseMapping),
      );
      final result = await repo.getCertifications(
        employeeId: '10',
        courseId: '107',
      );
      expect(result.single.courseName, 'Curso LMS');
      expect(result.single.courseId, '107');
      expect(result.single.completedAt, DateTime(2025, 1, 15));
      await client.dispose();
    },
  );

  test(
    'Audit hooks record success/failure without inventing insert/update counts',
    () async {
      final audit = Audit();
      final service = ImportAuditService(audit: audit);
      await service.run(
        fileType: 'horas_crm',
        fileName: 'file.xlsx',
        process: () async => const UpsertResult(processedRecords: 1),
      );
      expect(audit.records.single.status, ImportStatus.completed);
      expect(audit.records.single.inserted, isNull);
      expect(audit.records.single.updated, isNull);
      await expectLater(
        service.run(
          fileType: 'horas_crm',
          fileName: 'file.xlsx',
          process: () async => throw const FormatException('Invalid data'),
        ),
        throwsFormatException,
      );
      expect(audit.records.last.status, ImportStatus.failed);
      expect(audit.records.last.errors, isNotEmpty);
    },
  );
}
