import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail_service.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_repository_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';

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

final employeeDetailServiceProvider = Provider<EmployeeDetailService>(
  (ref) => EmployeeDetailService(
    records: ref.watch(timeEntryRecordsServiceProvider),
    periods: ref.watch(teamsServiceProvider).periods,
  ),
);

/// Employee detail recalculated for the selected global period.
final employeeDetailProvider = FutureProvider.family<EmployeeDetail?, String>((
  ref,
  employeeId,
) async {
  final employees = await ref.watch(employeesProvider.future);
  final courses = await ref.watch(coursesProvider.future);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  final complianceService = await ref.watch(complianceServiceProvider.future);
  final hasPeriodData = await ref.watch(hasTeamPeriodDataProvider.future);
  return ref
      .watch(employeeDetailServiceProvider)
      .build(
        employeeId: employeeId,
        employees: employees,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        period: ref.watch(periodFilterProvider),
        complianceService: complianceService,
        hasPeriodData: hasPeriodData,
      );
});
