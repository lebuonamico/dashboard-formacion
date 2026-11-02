import 'package:app_finnegans/features/imports/domain/import_record.dart';

abstract interface class ImportRecordsRepository {
  Future<void> register(ImportRecord record);
}
