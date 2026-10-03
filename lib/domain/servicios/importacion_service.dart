import 'package:app_finnegans/domain/modelos/registro_importacion.dart';
import 'package:app_finnegans/domain/repositorios/importaciones_repository.dart';

class ImportacionService {
  final ImportacionesRepository? auditoria;
  const ImportacionService({this.auditoria});

  Future<void> persistir({
    required String tipoArchivo,
    required String nombreArchivo,
    required int registrosProcesados,
    required Future<void> Function() guardar,
  }) async {
    final fechaHora = DateTime.now().toUtc();
    try {
      await guardar();
    } catch (error) {
      // Audit failure must not replace the original persistence error.
      try {
        await auditoria?.registrar(
          RegistroImportacion(
            tipoArchivo: tipoArchivo,
            nombreArchivo: nombreArchivo,
            fechaHora: fechaHora,
            estado: EstadoImportacion.fallida,
            registrosProcesados: registrosProcesados,
            errores: [error.toString()],
          ),
        );
      } catch (_) {
        /* No physical audit backend is configured yet. */
      }
      rethrow;
    }
    try {
      await auditoria?.registrar(
        RegistroImportacion(
          tipoArchivo: tipoArchivo,
          nombreArchivo: nombreArchivo,
          fechaHora: fechaHora,
          estado: EstadoImportacion.completada,
          registrosProcesados: registrosProcesados,
        ),
      );
    } catch (error) {
      throw FormatException(
        'Los datos se guardaron, pero falló el registro de importación: $error',
      );
    }
  }
}
