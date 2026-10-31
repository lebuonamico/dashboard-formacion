import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/certifications/domain/certification_record.dart';
import 'package:app_finnegans/features/certifications/domain/certification_stats_service.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/lms_certifications_repository_provider.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/courses/presentation/providers/course_services_providers.dart';
import 'package:app_finnegans/features/courses/domain/course_catalog_service.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';

final lmsCertificationsProvider = FutureProvider<List<LmsCertification>>((
  ref,
) async {
  final repo = ref.watch(lmsCertificationsRepositoryProvider);
  // Solo las finalizaciones de los colaboradores que ve el usuario.
  final employeeIds = await ref.watch(visibleEmployeeIdsProvider.future);
  final certifications = await repo.getCertifications();
  if (employeeIds == null) return certifications;
  return certifications
      .where((certification) => employeeIds.contains(certification.employeeId))
      .toList();
});

final certificationStatsServiceProvider = Provider<CertificationStatsService>(
  (ref) => CertificationStatsService(
    classification: ref.watch(courseClassificationServiceProvider),
  ),
);

final joinedCertificationsProvider = FutureProvider<List<CertificationRecord>>((
  ref,
) async {
  final service = ref.watch(certificationStatsServiceProvider);
  return service.join(
    certifications: await ref.watch(lmsCertificationsProvider.future),
    employees: await ref.watch(employeesProvider.future),
    courses: await ref.watch(coursesProvider.future),
  );
});

final certificationKpisProvider = FutureProvider<CertificationKpis>((
  ref,
) async {
  final records = await ref.watch(joinedCertificationsProvider.future);
  return ref.watch(certificationStatsServiceProvider).kpis(records);
});

FilterRow certificationFilterRow(
  CertificationRecord item,
  Map<String, String> courseIdsByName,
) {
  final courseId = const CourseCatalogService().courseIdFor(
    item.certification.courseId,
    item.certification.courseName,
    courseIdsByName,
  );
  return FilterRow(
    {
      personFilterDimension: item.certification.employeeId.trim(),
      courseFilterDimension: courseId,
      'Área': item.employee?.area ?? '',
      'Equipo': item.employee?.team ?? '',
      'Tipo': item.lmsCategory?.label ?? '',
      'Estado': item.certification.isCompleted ? 'Finalizado' : 'Pendiente',
    },
    labels: {
      personFilterDimension: personFilterLabel(
        item.employee?.fullName ?? '',
        item.certification.employeeId,
      ),
      courseFilterDimension: courseFilterLabel(
        item.certification.courseName,
        courseId,
      ),
    },
  );
}

final certificationFilterRowsProvider = FutureProvider<List<FilterRow>>((
  ref,
) async {
  final courseIds = await ref.watch(courseIdsByNameProvider.future);
  final items = await ref.watch(joinedCertificationsProvider.future);
  return items.map((item) => certificationFilterRow(item, courseIds)).toList();
});

final filteredCertificationsProvider =
    FutureProvider<List<CertificationRecord>>((ref) async {
      final selection = ref
          .watch(dataFilterSelectionProvider(DataFilterScope.certifications))
          .values;
      final filters = ref.watch(dataFilterServiceProvider);
      final courseIds = await ref.watch(courseIdsByNameProvider.future);
      final items = await ref.watch(joinedCertificationsProvider.future);
      return items
          .where(
            (item) => filters.matches(
              selection,
              certificationFilterRow(item, courseIds),
            ),
          )
          .toList();
    });
