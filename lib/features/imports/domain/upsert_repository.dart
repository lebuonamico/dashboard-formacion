import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

// Capability used by importers without coupling them to Supabase.
abstract interface class UpsertRepository<T> {
  Future<void> upsert(List<T> items);
}

// Masters synchronize a complete, validated snapshot; movements only UPSERT.
abstract interface class SnapshotRepository<T> {
  Future<UpsertResult> syncSnapshotWithResult(List<T> items);
}

abstract interface class CountedUpsertRepository<T>
    implements UpsertRepository<T> {
  Future<UpsertResult> upsertWithResult(List<T> items);
}
