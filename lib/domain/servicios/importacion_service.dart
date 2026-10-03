import 'package:app_finnegans/domain/modelos/registro_importacion.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';
import 'package:app_finnegans/domain/repositorios/importaciones_repository.dart';

class ImportacionService {
  final ImportacionesRepository? auditoria;
  const ImportacionService({this.auditoria});

  Future<ResultadoUpsert> ejecutar({
    required String tipoArchivo,
    required String nombreArchivo,
    required Future<ResultadoUpsert> Function() procesar,
    Future<void> Function()? refrescar,
  }) async {
    final fechaHora = DateTime.now().toUtc();
    var resultado = ResultadoUpsert.empty;
    var persistida = false;
    var auditada = false;
    try {
      resultado = await procesar();
      persistida = true;
      await auditoria?.registrar(
        RegistroImportacion(
          tipoArchivo: tipoArchivo,
          nombreArchivo: nombreArchivo,
          fechaHora: fechaHora,
          estado: EstadoImportacion.completada,
          registrosProcesados: resultado.registrosProcesados,
          insertados: resultado.insertados,
          actualizados: resultado.actualizados,
        ),
      );
      auditada = true;
      await refrescar?.call();
      return resultado;
    } catch (error, stackTrace) {
      if (persistida && auditada) {
        // The import is durable; a failed read must not create a second audit.
        throw FormatException(
          'Los datos se guardaron, pero no se pudo actualizar la pantalla: $error',
        );
      }
      try {
        await auditoria?.registrar(
          RegistroImportacion(
            tipoArchivo: tipoArchivo,
            nombreArchivo: nombreArchivo,
            fechaHora: fechaHora,
            estado: EstadoImportacion.fallida,
            registrosProcesados: resultado.registrosProcesados,
            insertados: resultado.insertados,
            actualizados: resultado.actualizados,
            errores: [error.toString()],
          ),
        );
      } catch (_) {
        // Preserve the original failure when the audit backend also fails.
      }
      if (persistida && !auditada) {
        throw FormatException(
          'Los datos se guardaron, pero falló el registro de importación: $error',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // Compatibility for consumers that cannot yet report persistence counts.
  Future<void> persistir({
    required String tipoArchivo,
    required String nombreArchivo,
    required int registrosProcesados,
    required Future<void> Function() guardar,
  }) async {
    await ejecutar(
      tipoArchivo: tipoArchivo,
      nombreArchivo: nombreArchivo,
      procesar: () async {
        await guardar();
        return ResultadoUpsert(registrosProcesados: registrosProcesados);
      },
    );
  }
}
