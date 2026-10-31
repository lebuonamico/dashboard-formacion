import 'package:collection/collection.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_repository_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry_record.dart';

/// Payroll as the database returns it for the session (with RLS), read
/// once. Shared by [employeesProvider] and [sessionEmployeeProvider].
final payrollProvider = FutureProvider<List<Employee>>((ref) {
  // With RLS each user gets different rows: another session reads again.
  ref.watch(sessionDataProvider);
  return ref.watch(employeesRepositoryProvider).getEmployees();
});

/// Payroll the session user sees, by role and the areas or teams they lead.
final employeesProvider = FutureProvider<List<Employee>>((ref) async {
  // The payroll goes first: if it fails, that is the error to show.
  final scopes = ref.watch(userScopeServiceProvider);
  final employees = await ref.watch(payrollProvider.future);
  final scope = await ref.watch(userScopeProvider.future);
  return employees
      .where((employee) => scopes.includesEmployee(scope, employee))
      .toList();
});

/// Employee IDs the user sees, or `null` if they see the whole company.
/// Filters hours and certifications with the same criterion as the payroll.
final visibleEmployeeIdsProvider = FutureProvider<Set<String>?>((ref) async {
  final scope = await ref.watch(userScopeProvider.future);
  if (scope.isTotal) return null;
  final employees = await ref.watch(employeesProvider.future);
  return {for (final employee in employees) employee.employeeId};
});

final employeeHistoryProvider = FutureProvider<List<EmployeeHistoryEntry>>((
  ref,
) {
  // With RLS each user gets different history rows: read again when someone
  // else signs in on the same tab.
  ref.watch(sessionDataProvider);
  return ref.watch(employeeHistoryRepositoryProvider).getEmployeeHistory();
});

FilterRow employeeFilterRow(Employee employee) => FilterRow(
  {
    personFilterDimension: employee.employeeId.trim(),
    'Área': employee.area,
    'Equipo': employee.team,
    'Líder': employee.manager,
    'Email': employee.email,
    'Seniority': employee.seniority.label,
  },
  labels: {
    personFilterDimension: personFilterLabel(
      employee.fullName,
      employee.employeeId,
    ),
  },
);

final employeeFilterRowsProvider = FutureProvider<List<FilterRow>>((ref) async {
  final employees = await ref.watch(employeesProvider.future);
  return employees.map(employeeFilterRow).toList();
});

final filteredEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  final selection = ref
      .watch(dataFilterSelectionProvider(DataFilterScope.employees))
      .values;
  final filters = ref.watch(dataFilterServiceProvider);
  final employees = await ref.watch(employeesProvider.future);
  return employees
      .where(
        (employee) => filters.matches(selection, employeeFilterRow(employee)),
      )
      .toList();
});

/// A course the employee logged in the CRM as taught, with the period's hours.
class TaughtCourseStats {
  final String code;
  final String name;
  final String area;
  final double hours;

  const TaughtCourseStats({
    required this.code,
    required this.name,
    required this.area,
    required this.hours,
  });
}

class EmployeeDetailViewModel {
  final Employee employee;
  final EmployeeCompliance compliance;
  final List<CrmTimeEntryRecord> timeEntriesCrm;
  final List<LmsCertification> lmsCertifications;
  final Map<String, Course> coursesByName;
  final List<TaughtCourseStats> taughtCourses;
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

  /// Looks the course up in the catalog by normalized name.
  Course? courseByName(String name) => coursesByName[normalizeKey(name)];
}

/// Employee detail recalculated for the selected global period.
final employeeDetailProvider =
    FutureProvider.family<EmployeeDetailViewModel?, String>((
      ref,
      employeeId,
    ) async {
      final employees = await ref.watch(employeesProvider.future);
      final courses = await ref.watch(coursesProvider.future);
      final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
      final certifications = await ref.watch(lmsCertificationsProvider.future);
      final period = ref.watch(periodFilterProvider);
      final month = period.month;
      final year = period.year;
      final complianceService = await ref.watch(
        complianceServiceProvider.future,
      );
      final teamsService = ref.watch(teamsServiceProvider);
      final records = ref.watch(timeEntryRecordsServiceProvider);
      final isAnnual = period.scope == PeriodScope.annual;

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
      // Every certification dated in the period is shown.
      final periodCertifications = employeeCertifications.where((item) {
        final date = item.completedAt;
        if (date == null || date.year != year) return false;
        return isAnnual || date.month == month;
      }).toList()..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

      final compliance = teamsService.periods.employeeCompliance(
        employee: employee,
        courses: courses,
        timeEntries: employeeTimeEntries,
        certifications: employeeCertifications,
        period: period,
        complianceService: complianceService,
      );

      final coursesByName = {
        for (final course in courses) normalizeKey(course.name): course,
      };
      final timeEntriesCrm = periodTimeEntries
          .map(
            (timeEntry) => records.record(
              timeEntry,
              employee: employee,
              course: coursesByName[normalizeKey(timeEntry.courseName)],
            ),
          )
          .toList();

      // Taught courses come from the CRM classification "Dictado de
      // capacitaciones".
      final taughtByCourse = groupBy(
        timeEntriesCrm.where((item) => item.isTaught),
        (item) {
          final courseId =
              item.course?.id.trim() ?? item.timeEntry.courseId?.trim();
          return courseId != null && courseId.isNotEmpty
              ? 'id:$courseId'
              : 'nombre:${normalizeKey(item.timeEntry.courseName)}';
        },
      );
      final taught = taughtByCourse.values.map((items) {
        final first = items.first;
        final course = first.course;
        return TaughtCourseStats(
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
          .map((item) => normalizeKey(item.courseName))
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
