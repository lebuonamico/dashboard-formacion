import 'package:app_finnegans/core/data/supabase_codes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';

class SupabaseImportRecordsRepository implements ImportRecordsRepository {
  final SupabaseClient _client;

  SupabaseImportRecordsRepository(this._client);

  @override
  Future<void> register(ImportRecord record) async {
    await _client.schema('public').from('importaciones').insert({
      'tipo_archivo': record.fileType,
      'nombre_archivo': record.fileName,
      'fecha_hora': record.dateTime.toIso8601String(),
      'estado': importStatusToDb(record.status),
      'registros_procesados': record.processedRecords,
      'insertados': record.inserted,
      'actualizados': record.updated,
      'errores': record.errors,
    });
  }
}
