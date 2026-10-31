import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

/// CRM hours only add or replace entries by transaction ID. Each entry names
/// its course, which must match exactly one course of the catalog.
class ImportCrmTimeEntries {
  static const fileType = 'horas_crm';

  final ImportAuditService audit;
  final ImportFileParser<List<CrmTimeEntry>> parser;
  final CrmTimeEntriesRepository timeEntries;

  const ImportCrmTimeEntries({
    required this.audit,
    required this.parser,
    required this.timeEntries,
  });

  /// [loadCatalog] gives the catalog already loaded by the app; it is awaited
  /// inside the audited process, so a failure to read it is audited too.
  Future<UpsertResult> call(
    ImportFile file, {
    required Future<List<Course>> Function() loadCatalog,
    Future<void> Function()? refresh,
  }) => audit.run(
    fileType: fileType,
    fileName: file.name,
    refresh: refresh,
    process: () async {
      final entries = parser.parse(file);
      final catalog = await loadCatalog();
      final resolved = <String, Course>{};
      final withCourse = entries.map((entry) {
        final course = resolved[normalizeLoose(entry.courseName)] ??=
            courseResolver(entry.courseName, catalog);
        return entry.copyWith(courseName: course.name, courseId: course.id);
      }).toList();
      final written = await timeEntries.upsert(withCourse);
      return UpsertResult(
        processedRecords: withCourse.length,
        inserted: written.inserted,
        updated: written.updated,
      );
    },
  );
}
