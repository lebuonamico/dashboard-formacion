import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/core/data/supabase_table.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/data/course_name_hydration.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseLmsCertificationsRepository
    implements LmsCertificationsRepository {
  static final mapping = SupabaseTableMapping(
    table: 'finalizaciones_cursos',
    conflictFields: ['employeeId', 'courseId'],
    columns: {
      'employeeId': 'legajo',
      'courseId': 'curso_id',
      'isCompleted': 'finalizo',
      'completedAt': 'fecha_finalizacion',
    },
  );

  final SupabaseTable _table;
  final CoursesRepository _courses;

  SupabaseLmsCertificationsRepository(SupabaseClient client, this._courses)
    : _table = SupabaseTable(client, mapping);

  @override
  Future<List<LmsCertification>> getCertifications() async {
    final rows = await withCourseNames(await _table.read(), _courses);
    return rows.map(LmsCertification.fromJson).toList();
  }

  @override
  Future<UpsertResult> upsert(List<LmsCertification> certifications) async {
    if (certifications.isEmpty) return UpsertResult.empty;
    if (certifications.any(
      (item) => item.isCompleted && item.completedAt == null,
    )) {
      throw const FormatException('Falta la fecha de finalización.');
    }
    final catalog = await _courses.getCourses();
    final resolved = <String, Course>{};
    final written = await _table.upsert(
      certifications.map((item) {
        final course = resolved[normalizeCourseName(item.courseName)] ??=
            courseResolver(item.courseName, catalog);
        return {...item.toJson(), 'courseId': course.id};
      }).toList(),
    );
    return UpsertResult(
      processedRecords: certifications.length,
      inserted: written.inserted,
      updated: written.updated,
    );
  }
}
