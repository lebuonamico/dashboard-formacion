import 'dart:convert';
import 'dart:math';

import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/features/certifications/data/in_memory_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/data/supabase_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/data/supabase_courses_repository.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/time_entries/data/in_memory_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/data/supabase_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Course course({String id = '107', String name = 'Curso LMS'}) => Course(
  id: id,
  name: name,
  category: CourseCategory.businessSkills,
  courseArea: 'Solo local',
  instructorEmployeeId: 'Solo local',
  workloadHours: 4,
);

Map<String, dynamic> _courseRow({
  String id = '107',
  String name = 'Curso LMS',
}) => {
  'id_curso': id,
  'nombre': name,
  'clasificacion': 'habilidadesDeNegocio',
  'carga_horaria': 4,
  'activo': true,
};

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
      () => CrmTimeEntry.fromJson({'date': 'invalid'}),
      throwsFormatException,
    );
    expect(
      () => LmsCertification.fromJson({'completedAt': '2025-02-31'}),
      throwsFormatException,
    );
  });

  test(
    'In-memory UPSERT preserves old CRM data and updates the same transaction',
    () async {
      CrmTimeEntry item(String id, int month, double hours) => CrmTimeEntry(
        id: id,
        courseName: 'Curso LMS',
        courseId: '107',
        employeeId: '10',
        date: DateTime(2025, month, 1),
        hours: hours,
        kind: TimeEntryKind.taken,
      );
      final repo = InMemoryCrmTimeEntriesRepository([item('old', 1, 2)]);

      final inserted = await repo.upsert([item('new', 2, 3)]);
      final updated = await repo.upsert([item('new', 2, 4)]);

      expect((inserted.inserted, inserted.updated), (1, 0));
      expect((updated.inserted, updated.updated), (0, 1));
      final all = await repo.getTimeEntries();
      expect(all.length, 2);
      expect(all.singleWhere((i) => i.id == 'old').hours, 2);
      expect(all.singleWhere((i) => i.id == 'new').hours, 4);
    },
  );

  test(
    'In-memory completions keep one row per employee/course and repeated import is idempotent',
    () async {
      final repo = InMemoryLmsCertificationsRepository([]);
      final january = LmsCertification(
        employeeId: '10',
        courseName: 'Curso LMS',
        isCompleted: true,
        completedAt: DateTime(2025, 1, 1),
      );
      final february = LmsCertification(
        employeeId: '10',
        courseName: ' curso lms ',
        isCompleted: true,
        completedAt: DateTime(2025, 2, 1),
      );

      final first = await repo.upsert([january]);
      await repo.upsert([february]);
      final repeated = await repo.upsert([february]);

      expect((first.inserted, first.updated), (1, 0));
      expect((repeated.inserted, repeated.updated), (0, 1));
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
          for (var i = 0; i < count; i++) _courseRow(id: '${offset + i}'),
        ], total: total);
      }),
    );
    final courses = await SupabaseCoursesRepository(client).getCourses();
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

  test('Physical mappings are explicit and exclude non-contract fields', () {
    final mapping = SupabaseCoursesRepository.mapping;
    expect(
      () => SupabaseTableMapping(table: '', columns: {}, conflictFields: []),
      throwsArgumentError,
    );
    expect(() => mapping.column('courseArea'), throwsStateError);
    expect(
      mapping.encode(course().toJson()).keys,
      unorderedEquals([
        'id_curso',
        'nombre',
        'clasificacion',
        'carga_horaria',
        'activo',
      ]),
    );
  });

  test('The catalog is read once and HTTP errors propagate', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return _rows(request, []);
      }),
    );
    final courses = SupabaseCoursesRepository(client);
    await SupabaseCrmTimeEntriesRepository(client, courses).getTimeEntries();
    expect(requests.single.url.path, '/rest/v1/horas_capacitacion');

    final before = requests.length;
    await courses.getCourses();
    await courses.getCourses();
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
      SupabaseCoursesRepository(denied).getCourses(),
      throwsA(isA<PostgrestException>()),
    );
    await client.dispose();
    await denied.dispose();
  });

  test(
    'Supabase UPSERT resolves FK by catalog name and retains CRM source fields',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method != 'GET') {
            return http.Response('', 201, request: request);
          }
          return _rows(request, [
            if (request.url.path.endsWith('/cursos')) _courseRow(),
          ]);
        }),
      );
      final courses = SupabaseCoursesRepository(client);
      final hours = SupabaseCrmTimeEntriesRepository(client, courses);
      await hours.upsert([
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
      expect(post.url.queryParameters['on_conflict'], 'transaccion_id');
      expect(post.headers['prefer'], contains('resolution=merge-duplicates'));
      final row = (jsonDecode(post.body) as List).single as Map;
      expect(row['curso_id'], '107');
      expect(row['caso'], 'Choras - 90');
      expect(row['clasificacion'], 'CRM original');
      expect(row.keys, isNot(contains('kind')));
      expect(row.keys, isNot(contains('courseName')));
      expect(requests.any((r) => r.method == 'DELETE'), isFalse);

      await courses.upsert([course()]);
      final courseRow = (jsonDecode(requests.last.body) as List).single as Map;
      expect(courseRow, {
        'id_curso': '107',
        'nombre': 'Curso LMS',
        'clasificacion': 'habilidadesDeNegocio',
        'carga_horaria': 4.0,
        'activo': true,
      });
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
          final row = request.url.path.endsWith('/finalizaciones_cursos')
              ? {
                  'legajo': '10',
                  'curso_id': '107',
                  'finalizo': true,
                  'fecha_finalizacion': '2025-01-15',
                }
              : _courseRow();
          return _rows(request, [row]);
        }),
      );
      final repo = SupabaseLmsCertificationsRepository(
        client,
        SupabaseCoursesRepository(client),
      );
      final result = await repo.getCertifications();
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
