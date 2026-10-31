import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/core/data/supabase_table.dart';
import 'package:app_finnegans/features/courses/data/course_category_codes.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCoursesRepository implements CoursesRepository {
  static final mapping = SupabaseTableMapping(
    table: 'cursos',
    conflictFields: ['id'],
    columns: {
      'id': 'id_curso',
      'name': 'nombre',
      'category': 'clasificacion',
      'workloadHours': 'carga_horaria',
      'isActive': 'activo',
    },
  );

  final SupabaseTable _table;

  SupabaseCoursesRepository(SupabaseClient client)
    : _table = SupabaseTable(client, mapping);

  /// The catalog is small and read by courses, hours, completions and the
  /// imports: it is requested once and reused until this app changes it.
  Future<List<Course>>? _catalog;

  @override
  Future<List<Course>> getCourses() {
    final read = _catalog ??= _table.read().then(
      (rows) => rows
          .map(
            (row) => Course.fromJson({
              ...row,
              'category':
                  courseCategoryFromDb(row['category']) ?? row['category'],
            }),
          )
          .toList(),
    );
    // A failed read is not cached: the next request tries again.
    read.catchError((Object _) {
      if (identical(_catalog, read)) _catalog = null;
      return const <Course>[];
    });
    return read;
  }

  @override
  Future<UpsertResult> upsert(List<Course> courses) async {
    try {
      final written = await _table.upsert(
        courses
            .map(
              (course) => {
                'id': course.id,
                'name': course.name.trim(),
                'category': courseCategoryToDb(course.category),
                'workloadHours': course.workloadHours,
                'isActive': course.isActive,
              },
            )
            .toList(),
      );
      return UpsertResult(
        processedRecords: courses.length,
        inserted: written.inserted,
        updated: written.updated,
      );
    } finally {
      _catalog = null;
    }
  }
}
