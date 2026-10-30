import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

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

final lmsCertificationSearchProvider = StateProvider<String>((ref) => '');

/// `null` muestra todas, `true` solo las finalizadas y `false` las pendientes.
final certificationStatusFilterProvider = StateProvider<bool?>((ref) => null);

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
    Provider<AsyncValue<List<CertificationViewModel>>>((ref) {
      final certificationsAsync = ref.watch(lmsCertificationsProvider);
      final employeesAsync = ref.watch(employeesProvider);
      final coursesAsync = ref.watch(coursesProvider);

      if (certificationsAsync.isLoading ||
          employeesAsync.isLoading ||
          coursesAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (certificationsAsync.hasError) {
        return AsyncValue.error(
          certificationsAsync.error!,
          certificationsAsync.stackTrace!,
        );
      }

      if (employeesAsync.hasError) {
        return AsyncValue.error(
          employeesAsync.error!,
          employeesAsync.stackTrace!,
        );
      }

      if (coursesAsync.hasError) {
        return AsyncValue.error(coursesAsync.error!, coursesAsync.stackTrace!);
      }

      final employeeMap = {
        for (final e in employeesAsync.value ?? <Employee>[]) e.employeeId: e,
      };
      // Mismo normalizador que el cálculo de cumplimiento: así el aviso de
      // "fuera de catálogo" coincide con lo que realmente no acredita.
      final courseMap = {
        for (final course in coursesAsync.value ?? <Course>[])
          ComplianceService.normalizeCourseName(course.name): course,
      };

      final viewModels = [
        for (final certification
            in certificationsAsync.value ?? <LmsCertification>[])
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

      return AsyncValue.data(viewModels);
    });

final filteredCertificationsProvider =
    Provider<AsyncValue<List<CertificationViewModel>>>((ref) {
      final completeAsync = ref.watch(joinedCertificationsProvider);
      final query = ref
          .watch(lmsCertificationSearchProvider)
          .trim()
          .toLowerCase();
      final statusFilter = ref.watch(certificationStatusFilterProvider);
      final selection = ref.watch(dataFilterSelectionProvider('lms'));
      final courseIds = ref.watch(courseFilterIdentifiersProvider);

      return completeAsync.whenData((items) {
        return items.where((vm) {
          final emp = vm.employee;
          final matchesQuery =
              query.isEmpty ||
              vm.certification.employeeId.toLowerCase().contains(query) ||
              vm.certification.courseName.toLowerCase().contains(query) ||
              (emp != null &&
                  ('${emp.firstName} ${emp.lastName}'.toLowerCase().contains(
                        query,
                      ) ||
                      emp.area.toLowerCase().contains(query) ||
                      emp.team.toLowerCase().contains(query)));

          final matchesStatus =
              statusFilter == null ||
              vm.certification.isCompleted == statusFilter;

          return matchesQuery &&
              matchesStatus &&
              matchesDataFilters(
                selection,
                certificationFilterRow(vm, courseIdsByName: courseIds),
              );
        }).toList();
      });
    });
