import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

/// LMS completions only add or replace entries by employee and course: a
/// partial report never marks the absent ones as not completed.
class ImportLmsCertifications {
  static const fileType = 'finalizaciones';

  final ImportAuditService audit;
  final ImportFileParser<List<LmsCertification>> parser;
  final LmsCertificationsRepository certifications;

  const ImportLmsCertifications({
    required this.audit,
    required this.parser,
    required this.certifications,
  });

  Future<UpsertResult> call(
    ImportFile file, {
    Future<void> Function()? refresh,
  }) => audit.run(
    fileType: fileType,
    fileName: file.name,
    refresh: refresh,
    process: () async {
      final parsed = parser.parse(file);
      final written = await certifications.upsert(parsed);
      return UpsertResult(
        processedRecords: parsed.length,
        inserted: written.inserted,
        updated: written.updated,
      );
    },
  );
}
