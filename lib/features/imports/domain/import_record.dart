enum ImportStatus { completed, failed }

/// Audit result; legacy repositories may leave persistence counts unknown.
class ImportRecord {
  final String fileType;
  final String fileName;
  final DateTime dateTime;
  final ImportStatus status;
  final int processedRecords;
  final int? inserted;
  final int? updated;
  final List<String> errors;

  const ImportRecord({
    required this.fileType,
    required this.fileName,
    required this.dateTime,
    required this.status,
    required this.processedRecords,
    this.inserted,
    this.updated,
    this.errors = const [],
  });
}
