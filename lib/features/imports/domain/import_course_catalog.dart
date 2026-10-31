import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/snapshot_sync_service.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

/// The catalog file is the current snapshot: absent courses are deactivated.
class ImportCourseCatalog {
  static const fileType = 'cursos_lms';

  final ImportAuditService audit;
  final ImportFileParser<List<Course>> parser;
  final CoursesRepository courses;
  final SnapshotSyncService snapshotSync;

  const ImportCourseCatalog({
    required this.audit,
    required this.parser,
    required this.courses,
    required this.snapshotSync,
  });

  Future<UpsertResult> call(
    ImportFile file, {
    Future<void> Function()? refresh,
  }) => audit.run(
    fileType: fileType,
    fileName: file.name,
    refresh: refresh,
    process: () => snapshotSync.syncCourseCatalog(courses, parser.parse(file)),
  );
}
