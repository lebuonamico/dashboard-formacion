import 'dart:convert';
import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';

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
  Future<void> upsertCertificaciones(List<CertificacionMoodle> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<CertificacionMoodle>) {
      await (this as UpsertRepository<CertificacionMoodle>).upsert(items);
      return;
    }
    final merged = <String, CertificacionMoodle>{};
    for (final item in [...await getCertificaciones(), ...items]) {
      merged[jsonEncode(item.toJson())] = item;
    }
    await replaceCertificaciones(merged.values.toList());
  }
}
