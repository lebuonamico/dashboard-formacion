import 'package:app_finnegans/core/data_filters/data_filters_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_repository.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Nómina tal como la devuelve la base para la sesión (con RLS), leída una
/// sola vez. La comparten [employeesProvider] y [sessionEmployeeProvider].
final payrollProvider = FutureProvider<List<Employee>>((ref) {
  // Con RLS cada usuario recibe filas distintas: otra sesión vuelve a leer.
  ref.watch(sessionDataProvider);
  return ref.watch(employeesRepositoryProvider).getEmployees();
});

/// Nómina que ve el usuario de la sesión, según su rol y las áreas o equipos
/// que lidera.
final employeesProvider = FutureProvider<List<Employee>>((ref) async {
  // La nómina va primero: si falla, ese es el error que tiene que verse.
  final employees = await ref.watch(payrollProvider.future);
  final scope = await ref.watch(userScopeProvider.future);
  return employees.where(scope.includesEmployee).toList();
});

/// Legajos que ve el usuario, o `null` si ve toda la empresa. Filtra las
/// horas y las finalizaciones con el mismo criterio que la nómina.
final visibleEmployeeIdsProvider = FutureProvider<Set<String>?>((ref) async {
  final scope = await ref.watch(userScopeProvider.future);
  if (scope.isTotal) return null;
  final employees = await ref.watch(employeesProvider.future);
  return {for (final employee in employees) employee.employeeId};
});

final employeeHistoryProvider = FutureProvider<List<EmployeeHistoryEntry>?>((
  ref,
) async {
  final repo = ref.watch(employeesRepositoryProvider);
  if (repo is! EmployeeHistoryRepository) return null;
  // Con RLS cada usuario recibe vigencias distintas: se vuelve a consultar
  // cuando entra otro en la misma pestaña.
  ref.watch(sessionDataProvider);
  // Leandro: llama a getHistorialEmpleados para consultar las vigencias sin escribir un historial paralelo.
  return (repo as EmployeeHistoryRepository).getEmployeeHistory();
});

final employeeSearchProvider = StateProvider<String>((ref) => '');
final seniorityFilterProvider = StateProvider<Seniority?>((ref) => null);

final filteredEmployeesProvider = Provider<AsyncValue<List<Employee>>>((ref) {
  final employeesAsync = ref.watch(employeesProvider);
  final query = ref.watch(employeeSearchProvider).toLowerCase();
  final seniorityFilter = ref.watch(seniorityFilterProvider);
  final selection = ref.watch(dataFilterSelectionProvider('personas'));

  return employeesAsync.whenData((employees) {
    return employees.where((emp) {
      final matchesQuery =
          emp.firstName.toLowerCase().contains(query) ||
          emp.lastName.toLowerCase().contains(query) ||
          emp.employeeId.toLowerCase().contains(query) ||
          emp.area.toLowerCase().contains(query) ||
          emp.team.toLowerCase().contains(query) ||
          emp.manager.toLowerCase().contains(query) ||
          emp.email.toLowerCase().contains(query);

      final matchesSeniority =
          seniorityFilter == null || emp.seniority == seniorityFilter;

      return matchesQuery &&
          matchesSeniority &&
          matchesDataFilters(selection, employeeFilterRow(emp));
    }).toList();
  });
});

/// Curso que el empleado cargó en el CRM como dictado, con las horas del período.
class TaughtCourseViewModel {
  final String code;
  final String name;
  final String area;
  final double hours;

  const TaughtCourseViewModel({
    required this.code,
    required this.name,
    required this.area,
    required this.hours,
  });
}

class EmployeeDetailViewModel {
  final Employee employee;
  final EmployeeCompliance compliance;
  final List<CrmTimeEntryViewModel> timeEntriesCrm;
  final List<LmsCertification> lmsCertifications;
  final Map<String, Course> coursesByName;
  final List<TaughtCourseViewModel> taughtCourses;
  final Set<String> completedCourses;

  EmployeeDetailViewModel({
    required this.employee,
    required this.compliance,
    required this.timeEntriesCrm,
    required this.lmsCertifications,
    required this.coursesByName,
    required this.taughtCourses,
    required this.completedCourses,
  });

  /// Busca el curso del catálogo por nombre normalizado.
  Course? courseByName(String name) =>
      coursesByName[ComplianceService.normalizeCourseName(name)];
}

/// Detalle del empleado recalculado para el período global seleccionado.
final employeeDetailProvider =
    FutureProvider.family<EmployeeDetailViewModel?, String>((
      ref,
      employeeId,
    ) async {
      final employees = await ref.watch(employeesProvider.future);
      final courses = await ref.watch(coursesProvider.future);
      final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
      final certifications = await ref.watch(lmsCertificationsProvider.future);
      final scope = ref.watch(periodScopeProvider);
      final month = ref.watch(periodMonthFilterProvider);
      final year = ref.watch(periodYearFilterProvider);
      final complianceService = await ref.watch(
        complianceServiceProvider.future,
      );
      final teamsService = ref.read(teamsServiceProvider);
      final isAnnual = scope == PeriodScope.annual;

      final employee = employees
          .where((emp) => emp.employeeId == employeeId)
          .firstOrNull;
      if (employee == null) return null;

      final employeeTimeEntries = timeEntries
          .where((timeEntry) => timeEntry.employeeId == employeeId)
          .toList();
      final employeeCertifications = certifications
          .where((item) => item.employeeId == employeeId)
          .toList();

      final periodTimeEntries = teamsService.periods.filterTimeEntriesByPeriod(
        timeEntries: employeeTimeEntries,
        year: year,
        month: month,
        isAnnual: isAnnual,
      );
      // Solo las finalizadas del período suman cumplimiento.
      final periodValidCertifications = teamsService.periods
          .filterCertificationsByPeriod(
            certifications: employeeCertifications,
            year: year,
            month: month,
            isAnnual: isAnnual,
          );
      // Para mostrar se incluyen todas las que tienen fecha en el período.
      final periodCertifications = employeeCertifications.where((item) {
        final date = item.completedAt;
        if (date == null || date.year != year) return false;
        return isAnnual || date.month == month;
      }).toList()..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

      var compliance = complianceService
          .calculateComplianceGlobal(
            employees: [employee],
            courses: courses,
            timeEntries: periodTimeEntries,
            lmsCertifications: periodValidCertifications,
            year: year,
            month: month,
          )
          .first;
      if (isAnnual) {
        // Objetivo del año: los 12 meses, cada uno con su versión del plan.
        compliance = EmployeeCompliance(
          employee: compliance.employee,
          creditedHours: compliance.creditedHours,
          declaredHours: compliance.declaredHours,
          requiredHours: complianceService.plans.requiredForYear(
            employee.seniority,
            year,
          ),
        );
      }

      final coursesByName = {
        for (final course in courses)
          ComplianceService.normalizeCourseName(course.name): course,
      };
      final timeEntriesCrm = periodTimeEntries
          .map(
            (timeEntry) => CrmTimeEntryViewModel(
              timeEntry: timeEntry,
              employee: employee,
              course:
                  coursesByName[ComplianceService.normalizeCourseName(
                    timeEntry.courseName,
                  )],
            ),
          )
          .toList();

      // Los dictados salen del CRM (Clasificación "Dictado de capacitaciones").
      final taughtByCourse = <String, List<CrmTimeEntryViewModel>>{};
      for (final item in timeEntriesCrm.where(
        (item) => item.timeEntry.isTaught,
      )) {
        final courseId =
            item.course?.id.trim() ?? item.timeEntry.courseId?.trim();
        final key = courseId != null && courseId.isNotEmpty
            ? 'id:$courseId'
            : 'nombre:${ComplianceService.normalizeCourseName(item.timeEntry.courseName)}';
        taughtByCourse.putIfAbsent(key, () => []).add(item);
      }
      final taught = taughtByCourse.values.map((items) {
        final first = items.first;
        final course = first.course;
        return TaughtCourseViewModel(
          code: course?.id ?? first.timeEntry.courseId ?? '',
          name: course?.name ?? first.timeEntry.courseName,
          area: course?.courseArea ?? first.timeEntry.courseDescription ?? '',
          hours: items.fold<double>(
            0,
            (total, item) => total + item.timeEntry.hours,
          ),
        );
      }).toList()..sort((a, b) => a.name.compareTo(b.name));
      final completedCourses = employeeCertifications
          .where((item) => item.isCompleted)
          .map((item) => ComplianceService.normalizeCourseName(item.courseName))
          .toSet();

      return EmployeeDetailViewModel(
        employee: employee,
        compliance: compliance,
        timeEntriesCrm: timeEntriesCrm,
        lmsCertifications: periodCertifications,
        coursesByName: coursesByName,
        taughtCourses: taught,
        completedCourses: completedCourses,
      );
    });
