import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/payroll_import.dart';
import 'package:app_finnegans/features/imports/domain/snapshot_sync_service.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';

/// The payroll file is the current snapshot of the staff. The areas and
/// teams it brings for the first time are registered before writing it, so
/// a failure there leaves no employee half written.
class ImportPayroll {
  static const fileType = 'nomina';

  final ImportAuditService audit;
  final ImportFileParser<PayrollImport> parser;
  final EmployeesRepository employees;
  final OrgStructureRepository orgStructure;
  final OrgStructureService orgStructureService;
  final SnapshotSyncService snapshotSync;

  const ImportPayroll({
    required this.audit,
    required this.parser,
    required this.employees,
    required this.orgStructure,
    required this.orgStructureService,
    required this.snapshotSync,
  });

  Future<UpsertResult> call(
    ImportFile file, {
    Future<void> Function()? refresh,
  }) => audit.run(
    fileType: fileType,
    fileName: file.name,
    refresh: refresh,
    process: () async {
      final payroll = parser.parse(file);
      final structure = await orgStructure.getStructure();
      await orgStructure.registerMissing(
        orgStructureService.missingFromPayroll(structure, payroll.employees),
      );
      final written = await snapshotSync.syncPayroll(
        employees,
        payroll.employees,
      );
      return UpsertResult(
        processedRecords: payroll.rowCount,
        inserted: written.inserted,
        updated: written.updated,
      );
    },
  );
}
