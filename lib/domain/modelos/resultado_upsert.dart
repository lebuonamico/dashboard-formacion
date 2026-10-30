/// Counts for a successfully persisted import batch.
/// Null counts mean the repository cannot distinguish inserts from updates.
class UpsertResult {
  final int processedRecords;
  final int? inserted;
  final int? updated;

  const UpsertResult({
    required this.processedRecords,
    this.inserted,
    this.updated,
  });

  static const empty = UpsertResult(
    processedRecords: 0,
    inserted: 0,
    updated: 0,
  );

  UpsertResult operator +(UpsertResult other) => UpsertResult(
    processedRecords: processedRecords + other.processedRecords,
    inserted: inserted == null || other.inserted == null
        ? null
        : inserted! + other.inserted!,
    updated: updated == null || other.updated == null
        ? null
        : updated! + other.updated!,
  );
}
