import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/core/data/supabase_table.dart';
import 'package:app_finnegans/features/courses/data/course_name_hydration.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';

class SupabaseCrmTimeEntriesRepository implements CrmTimeEntriesRepository {
  static final mapping = SupabaseTableMapping(
    table: 'horas_capacitacion',
    conflictFields: ['id'],
    columns: {
      'id': 'transaccion_id',
      'employeeId': 'legajo',
      'courseId': 'curso_id',
      'date': 'fecha',
      'caseRef': 'caso',
      'courseDescription': 'descripcion_curso',
      'classification': 'clasificacion',
      'project': 'proyecto',
      'projectItem': 'proyecto_item',
      'hours': 'horas_totales',
      'description': 'descripcion',
    },
  );

  final SupabaseTable _table;
  final CoursesRepository _courses;

  SupabaseCrmTimeEntriesRepository(SupabaseClient client, this._courses)
    : _table = SupabaseTable(client, mapping);

  @override
  Future<List<CrmTimeEntry>> getTimeEntries() async {
    final rows = await withCourseNames(await _table.read(), _courses);
    return rows.map(CrmTimeEntry.fromJson).toList();
  }

  @override
  Future<UpsertResult> upsert(List<CrmTimeEntry> timeEntries) async {
    if (timeEntries.isEmpty) return UpsertResult.empty;
    final catalog = await _courses.getCourses();
    final resolved = <String, Course>{};
    final written = await _table.upsert(
      timeEntries.map((entry) {
        final course = resolved[normalizeLoose(entry.courseName)] ??=
            courseResolver(entry.courseName, catalog);
        return {...entry.toJson(), 'courseId': course.id};
      }).toList(),
    );
    return UpsertResult(
      processedRecords: timeEntries.length,
      inserted: written.inserted,
      updated: written.updated,
    );
  }
}
