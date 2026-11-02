import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/lms_certifications_repository_provider.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_repository_provider.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_repository_providers.dart';
import 'package:app_finnegans/features/imports/data/course_catalog_file_parser.dart';
import 'package:app_finnegans/features/imports/data/crm_time_entries_file_parser.dart';
import 'package:app_finnegans/features/imports/data/in_memory_import_records_repository.dart';
import 'package:app_finnegans/features/imports/data/lms_certifications_file_parser.dart';
import 'package:app_finnegans/features/imports/data/payroll_file_parser.dart';
import 'package:app_finnegans/features/imports/data/spreadsheet_reader.dart';
import 'package:app_finnegans/features/imports/data/supabase_import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/imports/domain/import_course_catalog.dart';
import 'package:app_finnegans/features/imports/domain/import_crm_time_entries.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/import_lms_certifications.dart';
import 'package:app_finnegans/features/imports/domain/import_payroll.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/payroll_import.dart';
import 'package:app_finnegans/features/imports/domain/snapshot_sync_service.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_repository_provider.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/crm_time_entries_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final importRecordsRepositoryProvider = Provider<ImportRecordsRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseImportRecordsRepository(ref.watch(supabaseClientProvider))
      : InMemoryImportRecordsRepository(),
);

final importAuditServiceProvider = Provider<ImportAuditService>(
  (ref) => ImportAuditService(
    audit: ref.watch(importRecordsRepositoryProvider),
    now: ref.watch(clockProvider),
  ),
);

final snapshotSyncServiceProvider = Provider<SnapshotSyncService>(
  (ref) => const SnapshotSyncService(),
);

final spreadsheetReaderProvider = Provider<SpreadsheetReader>(
  (ref) => const SpreadsheetReader(),
);

final payrollFileParserProvider = Provider<ImportFileParser<PayrollImport>>(
  (ref) => PayrollFileParser(reader: ref.watch(spreadsheetReaderProvider)),
);

final courseCatalogFileParserProvider =
    Provider<ImportFileParser<List<Course>>>(
      (ref) =>
          CourseCatalogFileParser(reader: ref.watch(spreadsheetReaderProvider)),
    );

final crmTimeEntriesFileParserProvider =
    Provider<ImportFileParser<List<CrmTimeEntry>>>(
      (ref) => CrmTimeEntriesFileParser(
        reader: ref.watch(spreadsheetReaderProvider),
      ),
    );

final lmsCertificationsFileParserProvider =
    Provider<ImportFileParser<List<LmsCertification>>>(
      (ref) => LmsCertificationsFileParser(
        reader: ref.watch(spreadsheetReaderProvider),
      ),
    );

final importPayrollProvider = Provider<ImportPayroll>(
  (ref) => ImportPayroll(
    audit: ref.watch(importAuditServiceProvider),
    parser: ref.watch(payrollFileParserProvider),
    employees: ref.watch(employeesRepositoryProvider),
    orgStructure: ref.watch(orgStructureRepositoryProvider),
    orgStructureService: ref.watch(orgStructureServiceProvider),
    snapshotSync: ref.watch(snapshotSyncServiceProvider),
  ),
);

final importCourseCatalogProvider = Provider<ImportCourseCatalog>(
  (ref) => ImportCourseCatalog(
    audit: ref.watch(importAuditServiceProvider),
    parser: ref.watch(courseCatalogFileParserProvider),
    courses: ref.watch(coursesRepositoryProvider),
    snapshotSync: ref.watch(snapshotSyncServiceProvider),
  ),
);

final importCrmTimeEntriesProvider = Provider<ImportCrmTimeEntries>(
  (ref) => ImportCrmTimeEntries(
    audit: ref.watch(importAuditServiceProvider),
    parser: ref.watch(crmTimeEntriesFileParserProvider),
    timeEntries: ref.watch(crmTimeEntriesRepositoryProvider),
  ),
);

final importLmsCertificationsProvider = Provider<ImportLmsCertifications>(
  (ref) => ImportLmsCertifications(
    audit: ref.watch(importAuditServiceProvider),
    parser: ref.watch(lmsCertificationsFileParserProvider),
    certifications: ref.watch(lmsCertificationsRepositoryProvider),
  ),
);
