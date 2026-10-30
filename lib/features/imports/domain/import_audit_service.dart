import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';

class ImportAuditService {
  final ImportRecordsRepository? audit;
  const ImportAuditService({this.audit});

  Future<UpsertResult> run({
    required String fileType,
    required String fileName,
    required Future<UpsertResult> Function() process,
    Future<void> Function()? refresh,
  }) async {
    final dateTime = DateTime.now().toUtc();
    var result = UpsertResult.empty;
    var persisted = false;
    var audited = false;
    try {
      result = await process();
      persisted = true;
      await audit?.register(
        ImportRecord(
          fileType: fileType,
          fileName: fileName,
          dateTime: dateTime,
          status: ImportStatus.completed,
          processedRecords: result.processedRecords,
          inserted: result.inserted,
          updated: result.updated,
        ),
      );
      audited = true;
      await refresh?.call();
      return result;
    } catch (error, stackTrace) {
      if (persisted && audited) {
        // The import is durable; a failed read must not create a second audit.
        throw FormatException(
          'Los datos se guardaron, pero no se pudo actualizar la pantalla: $error',
        );
      }
      try {
        await audit?.register(
          ImportRecord(
            fileType: fileType,
            fileName: fileName,
            dateTime: dateTime,
            status: ImportStatus.failed,
            processedRecords: result.processedRecords,
            inserted: result.inserted,
            updated: result.updated,
            errors: [error.toString()],
          ),
        );
      } catch (_) {
        // Preserve the original failure when the audit backend also fails.
      }
      if (persisted && !audited) {
        throw FormatException(
          'Los datos se guardaron, pero falló el registro de importación: $error',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
