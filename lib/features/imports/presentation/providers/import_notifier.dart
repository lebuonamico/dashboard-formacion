import 'dart:async';

import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ImportOutcome = ({String fileName, UpsertResult result});
typedef PickImportFile = Future<ImportFile?> Function();
typedef ConfirmImport = Future<bool> Function(ImportFile file);

class ImportState {
  final Set<ImportFileType> inProgress;

  const ImportState({this.inProgress = const {}});

  ImportState copyWith({Set<ImportFileType>? inProgress}) =>
      ImportState(inProgress: inProgress ?? this.inProgress);
}

/// Kept alive: an import keeps running, and refreshes what it changed, after
/// leaving the settings screen.
final importProvider = AsyncNotifierProvider<ImportNotifier, ImportState>(
  ImportNotifier.new,
);

/// The four imports. A type is in progress from the moment it is requested,
/// while the file is being picked and confirmed: a second request of the same
/// type is ignored, and different types run side by side. Each one returns
/// null when cancelled and rethrows its error.
class ImportNotifier extends AsyncNotifier<ImportState> {
  @override
  FutureOr<ImportState> build() => const ImportState();

  Future<ImportOutcome?> importPayroll({
    required PickImportFile pickFile,
    required ConfirmImport confirm,
  }) => _run(
    ImportFileType.payroll,
    pickFile,
    confirm,
    (file) => ref.read(importPayrollProvider)(
      file,
      refresh: () async {
        ref.invalidate(orgStructureNotifierProvider);
        ref.invalidate(payrollProvider);
        ref.invalidate(employeeHistoryProvider);
        await Future.wait([
          ref.read(orgStructureNotifierProvider.future),
          ref.read(employeesProvider.future),
          ref.read(employeeHistoryProvider.future),
        ]);
      },
    ),
  );

  /// Renaming a course renames its hours and completions, which read the
  /// name from the catalog.
  Future<ImportOutcome?> importCourses({
    required PickImportFile pickFile,
    required ConfirmImport confirm,
  }) => _run(
    ImportFileType.courseCatalog,
    pickFile,
    confirm,
    (file) => ref.read(importCourseCatalogProvider)(
      file,
      refresh: () async {
        ref.invalidate(coursesProvider);
        ref.invalidate(crmTimeEntriesProvider);
        ref.invalidate(dashboardTimeEntriesProvider);
        ref.invalidate(lmsCertificationsProvider);
        await Future.wait([
          ref.read(coursesProvider.future),
          ref.read(crmTimeEntriesProvider.future),
          ref.read(dashboardTimeEntriesProvider.future),
          ref.read(lmsCertificationsProvider.future),
        ]);
      },
    ),
  );

  Future<ImportOutcome?> importTimeEntries({
    required PickImportFile pickFile,
    required ConfirmImport confirm,
  }) => _run(
    ImportFileType.timeEntries,
    pickFile,
    confirm,
    (file) => ref.read(importCrmTimeEntriesProvider)(
      file,
      loadCatalog: () => ref.read(coursesProvider.future),
      refresh: () async {
        ref.invalidate(crmTimeEntriesProvider);
        ref.invalidate(dashboardTimeEntriesProvider);
        await Future.wait([
          ref.read(crmTimeEntriesProvider.future),
          ref.read(dashboardTimeEntriesProvider.future),
        ]);
      },
    ),
  );

  Future<ImportOutcome?> importCertifications({
    required PickImportFile pickFile,
    required ConfirmImport confirm,
  }) => _run(
    ImportFileType.certifications,
    pickFile,
    confirm,
    (file) => ref.read(importLmsCertificationsProvider)(
      file,
      refresh: () async {
        ref.invalidate(lmsCertificationsProvider);
        await ref.read(lmsCertificationsProvider.future);
      },
    ),
  );

  Future<ImportOutcome?> _run(
    ImportFileType type,
    PickImportFile pickFile,
    ConfirmImport confirm,
    Future<UpsertResult> Function(ImportFile file) import,
  ) async {
    final current = state.value;
    if (current == null || current.inProgress.contains(type)) return null;
    _setInProgress(type, running: true);
    try {
      final file = await pickFile();
      if (file == null || !await confirm(file)) return null;
      return (fileName: file.name, result: await import(file));
    } finally {
      if (ref.mounted) _setInProgress(type, running: false);
    }
  }

  void _setInProgress(ImportFileType type, {required bool running}) {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        inProgress: running
            ? {...current.inProgress, type}
            : current.inProgress.difference({type}),
      ),
    );
  }
}
