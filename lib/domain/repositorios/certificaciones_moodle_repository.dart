import 'dart:convert';
import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/repositorios/eliminacion_por_mes_repository.dart';
import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';

abstract class CertificacionesMoodleRepository {
  Future<List<CertificacionMoodle>> getCertificaciones({
    String? legajo,
    String? cursoId,
  });
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  );
}

extension CertificacionesMoodleUpsert on CertificacionesMoodleRepository {
  Future<ResultadoUpsert> upsertCertificacionesConResultado(
    List<CertificacionMoodle> items,
  ) async {
    if (items.isEmpty) return ResultadoUpsert.empty;
    if (this is CountedUpsertRepository<CertificacionMoodle>) {
      return (this as CountedUpsertRepository<CertificacionMoodle>)
          .upsertConResultado(items);
    }
    await upsertCertificaciones(items);
    return ResultadoUpsert(registrosProcesados: items.length);
  }

  Future<void> upsertCertificaciones(List<CertificacionMoodle> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<CertificacionMoodle>) {
      await (this as UpsertRepository<CertificacionMoodle>).upsert(items);
      return;
    }
    final registros = [...await getCertificaciones(), ...items];
    final idsPorNombre = idsCursosCertificaciones(registros);
    final merged = <String, CertificacionMoodle>{};
    for (final item in registros) {
      merged[claveCertificacionMoodle(item, idsPorNombre)] = item;
    }
    await replaceCertificaciones(merged.values.toList());
  }
}

extension CertificacionesMoodleEliminacion on CertificacionesMoodleRepository {
  Future<int> eliminarCertificacionesDelMes({
    required int anio,
    required int mes,
  }) async {
    if (this is EliminacionPorMesRepository) {
      return (this as EliminacionPorMesRepository).eliminarMes(
        anio: anio,
        mes: mes,
      );
    }
    final periodo = MesConRegistros(anio: anio, mes: mes, cantidad: 0);
    final certificaciones = await getCertificaciones();
    final restantes = certificaciones.where((item) {
      final fecha = item.fechaFinalizacion;
      return fecha == null || !periodo.contiene(fecha);
    }).toList();
    await replaceCertificaciones(restantes);
    return certificaciones.length - restantes.length;
  }
}

Map<String, String> idsCursosCertificaciones(
  Iterable<CertificacionMoodle> items,
) => {
  for (final item in items)
    if (item.cursoId?.trim().isNotEmpty == true &&
        item.cursoNombre.trim().isNotEmpty)
      normalizarNombreCurso(item.cursoNombre): item.cursoId!,
};

String claveCertificacionMoodle(
  CertificacionMoodle item,
  Map<String, String> idsPorNombre,
) => jsonEncode([
  item.legajo,
  item.cursoId?.trim().isNotEmpty == true
      ? item.cursoId
      : idsPorNombre[normalizarNombreCurso(item.cursoNombre)] ??
            normalizarNombreCurso(item.cursoNombre),
]);
