import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/lms_certifications_repository_provider.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';

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

/// Certificación del LMS cruzada con la nómina y el catálogo.
class CertificationViewModel {
  final LmsCertification certification;
  final Employee? employee;
  final Course? course;

  const CertificationViewModel({
    required this.certification,
    required this.employee,
    required this.course,
  });

  /// Sin curso en el catálogo la finalización no acredita horas (regla
  /// triangular de CumplimientoService).
  bool get courseOutsideCatalog => course == null;

  bool get employeeIdOutsidePayroll => employee == null;

  bool get outsideCalculation =>
      courseOutsideCatalog || employeeIdOutsidePayroll;
}

/// Todas las certificaciones importadas, sin filtrar y ordenadas: las más
/// recientes primero y las que no tienen fecha (pendientes) al final.
final joinedCertificationsProvider =
    FutureProvider<List<CertificationViewModel>>((ref) async {
      final certifications = await ref.watch(lmsCertificationsProvider.future);
      final employees = await ref.watch(employeesProvider.future);
      final courses = await ref.watch(coursesProvider.future);

      final employeeMap = {for (final e in employees) e.employeeId: e};
      // Mismo normalizador que el cálculo de cumplimiento: así el aviso de
      // "fuera de catálogo" coincide con lo que realmente no acredita.
      final courseMap = {
        for (final course in courses)
          ComplianceService.normalizeCourseName(course.name): course,
      };

      final viewModels = [
        for (final certification in certifications)
          CertificationViewModel(
            certification: certification,
            employee: employeeMap[certification.employeeId],
            course:
                courseMap[ComplianceService.normalizeCourseName(
                  certification.courseName,
                )],
          ),
      ];

      viewModels.sort((a, b) {
        final dateA = a.certification.completedAt;
        final dateB = b.certification.completedAt;
        if (dateA != null && dateB != null) {
          final byDate = dateB.compareTo(dateA);
          if (byDate != 0) return byDate;
        } else if (dateA != null) {
          return -1;
        } else if (dateB != null) {
          return 1;
        }
        return a.certification.courseName.toLowerCase().compareTo(
          b.certification.courseName.toLowerCase(),
        );
      });

      return viewModels;
    });

FilterRow certificationFilterRow(
  CertificationViewModel item,
  Map<String, String> courseIdsByName,
) {
  final courseId = courseIdFor(
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
      'Tipo': item.course?.classificationLms?.label ?? '',
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
    FutureProvider<List<CertificationViewModel>>((ref) async {
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
