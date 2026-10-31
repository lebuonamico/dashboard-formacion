/// Counts for a successfully persisted import batch.
class UpsertResult {
  final int processedRecords;
  final int inserted;
  final int updated;

  const UpsertResult({
    required this.processedRecords,
    required this.inserted,
    required this.updated,
  });

  static const empty = UpsertResult(
    processedRecords: 0,
    inserted: 0,
    updated: 0,
  );

  UpsertResult operator +(UpsertResult other) => UpsertResult(
    processedRecords: processedRecords + other.processedRecords,
    inserted: inserted + other.inserted,
    updated: updated + other.updated,
  );
}
