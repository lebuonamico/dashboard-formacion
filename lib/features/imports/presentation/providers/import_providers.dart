import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/imports/data/in_memory_import_records_repository.dart';
import 'package:app_finnegans/features/imports/data/supabase_import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/snapshot_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final importRecordsRepositoryProvider = Provider<ImportRecordsRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseImportRecordsRepository(ref.watch(supabaseClientProvider))
      : InMemoryImportRecordsRepository(),
);

final importAuditServiceProvider = Provider<ImportAuditService>(
  (ref) =>
      ImportAuditService(audit: ref.watch(importRecordsRepositoryProvider)),
);

final snapshotSyncServiceProvider = Provider<SnapshotSyncService>(
  (ref) => const SnapshotSyncService(),
);
