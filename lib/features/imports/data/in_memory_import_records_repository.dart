import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';

class InMemoryImportRecordsRepository implements ImportRecordsRepository {
  final List<ImportRecord> _records = [];

  List<ImportRecord> get records => List.unmodifiable(_records);

  @override
  Future<void> register(ImportRecord record) async => _records.add(record);
}
