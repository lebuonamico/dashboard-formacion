import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

abstract interface class LmsCertificationsRepository {
  Future<List<LmsCertification>> getCertifications();

  /// One certification per employee and course: a new one replaces the
  /// previous state and absent pairs are kept.
  Future<UpsertResult> upsert(List<LmsCertification> certifications);
}
