import 'dart:convert';

import 'package:app_finnegans/features/certifications/data/lms_certifications_seed.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';

/// Without a database there may be no course ID: the course is identified by
/// its ID when known, and otherwise by the ID another certification of the
/// same course name already has, or by the name itself.
class InMemoryLmsCertificationsRepository
    implements LmsCertificationsRepository {
  final Map<String, LmsCertification> _certifications = {};

  InMemoryLmsCertificationsRepository([
    List<LmsCertification>? certifications,
  ]) {
    _merge(certifications ?? lmsCertificationsSeed);
  }

  @override
  Future<List<LmsCertification>> getCertifications() async => [
    ..._certifications.values,
  ];

  @override
  Future<UpsertResult> upsert(List<LmsCertification> certifications) async {
    final before = _certifications.length;
    final unique = _merge(certifications);
    final inserted = _certifications.length - before;
    return UpsertResult(
      processedRecords: certifications.length,
      inserted: inserted,
      updated: unique - inserted,
    );
  }

  int _merge(List<LmsCertification> certifications) {
    final records = [..._certifications.values, ...certifications];
    final idsByName = {
      for (final item in records)
        if (item.courseId?.trim().isNotEmpty == true &&
            item.courseName.trim().isNotEmpty)
          normalizeLoose(item.courseName): item.courseId!,
    };
    String keyOf(LmsCertification item) => jsonEncode([
      item.employeeId,
      item.courseId?.trim().isNotEmpty == true
          ? item.courseId
          : idsByName[normalizeLoose(item.courseName)] ??
                normalizeLoose(item.courseName),
    ]);

    final merged = {for (final item in records) keyOf(item): item};
    _certifications
      ..clear()
      ..addAll(merged);
    return certifications.map(keyOf).toSet().length;
  }
}
