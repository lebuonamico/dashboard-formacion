import 'dart:convert';
import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';

abstract class LmsCertificationsRepository {
  Future<List<LmsCertification>> getCertifications({
    String? employeeId,
    String? courseId,
  });
  Future<void> replaceCertifications(List<LmsCertification> certifications);
}

extension LmsCertificationsUpsert on LmsCertificationsRepository {
  Future<UpsertResult> upsertCertificationsWithResult(
    List<LmsCertification> items,
  ) async {
    if (items.isEmpty) return UpsertResult.empty;
    if (this is CountedUpsertRepository<LmsCertification>) {
      return (this as CountedUpsertRepository<LmsCertification>)
          .upsertWithResult(items);
    }
    await upsertCertifications(items);
    return UpsertResult(processedRecords: items.length);
  }

  Future<void> upsertCertifications(List<LmsCertification> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<LmsCertification>) {
      await (this as UpsertRepository<LmsCertification>).upsert(items);
      return;
    }
    final records = [...await getCertifications(), ...items];
    final idsByName = certificationCourseIds(records);
    final merged = <String, LmsCertification>{};
    for (final item in records) {
      merged[lmsCertificationKey(item, idsByName)] = item;
    }
    await replaceCertifications(merged.values.toList());
  }
}

Map<String, String> certificationCourseIds(Iterable<LmsCertification> items) =>
    {
      for (final item in items)
        if (item.courseId?.trim().isNotEmpty == true &&
            item.courseName.trim().isNotEmpty)
          normalizeCourseName(item.courseName): item.courseId!,
    };

String lmsCertificationKey(
  LmsCertification item,
  Map<String, String> idsByName,
) => jsonEncode([
  item.employeeId,
  item.courseId?.trim().isNotEmpty == true
      ? item.courseId
      : idsByName[normalizeCourseName(item.courseName)] ??
            normalizeCourseName(item.courseName),
]);
