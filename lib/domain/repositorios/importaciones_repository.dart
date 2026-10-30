import 'package:app_finnegans/domain/modelos/registro_importacion.dart';

abstract interface class ImportRecordsRepository {
  Future<void> register(ImportRecord record);
}
