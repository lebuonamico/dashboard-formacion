import 'package:app_finnegans/domain/modelos/registro_importacion.dart';

abstract interface class ImportacionesRepository {
  Future<void> registrar(RegistroImportacion registro);
}
