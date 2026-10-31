import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/projection/domain/projection_service.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';

export 'package:app_finnegans/features/projection/domain/projection.dart';
export 'package:app_finnegans/features/projection/domain/projection_service.dart';

final projectionServiceProvider = Provider<ProjectionService>(
  (ref) => ProjectionService(periods: ref.watch(teamsServiceProvider).periods),
);

/// Month the projection cuts at: the selected one in monthly; in annual,
/// the year's last month with data. `null` if the year has no data.
final annualProjectionCutoffMonthProvider = FutureProvider<int?>((ref) async {
  final year = ref.watch(periodFilterProvider).year;
  if (ref.watch(periodFilterProvider).scope == PeriodScope.monthly) {
    return ref.watch(periodFilterProvider).month;
  }
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  return ref
      .watch(teamsServiceProvider)
      .periods
      .lastMonthWithData(
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
      );
});

/// Compliance of each month with data from January to the cutoff month,
/// with the same eligible payroll and user scope as Teams and Areas. Shared by
/// every section; each one filters its employees.
final complianceByMonthProvider =
    FutureProvider<Map<int, List<EmployeeCompliance>>>((ref) async {
      final cutoffMonth = await ref.watch(
        annualProjectionCutoffMonthProvider.future,
      );
      if (cutoffMonth == null) return {};

      final year = ref.watch(periodFilterProvider).year;
      final employees = await ref.watch(employeesProvider.future);
      final history = await ref.watch(employeeHistoryProvider.future);
      final courses = await ref.watch(coursesProvider.future);
      final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
      final certifications = await ref.watch(lmsCertificationsProvider.future);
      final complianceService = await ref.watch(
        complianceServiceProvider.future,
      );
      final userScope = await ref.watch(userScopeProvider.future);
      final include = ref
          .watch(userScopeServiceProvider)
          .employeeFilter(userScope);
      final teamsService = ref.watch(teamsServiceProvider);

      return teamsService.periods.calculateComplianceByMonth(
        employees: employees,
        history: history,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
        throughMonth: cutoffMonth,
        complianceService: complianceService,
        includeEmployee: include,
      );
    });

/// Compliance variation of a section: `(area: null, team: null)` is the
/// whole visible payroll. Each month is filtered by where each employee was
/// that month, like Areas' and Teams' compliance, and accumulated with the
/// same calculation as the annual one.
final complianceVariationProvider =
    FutureProvider.family<ComplianceVariation?, ({String? area, String? team})>(
      (ref, section) async {
        final cutoffMonth = await ref.watch(
          annualProjectionCutoffMonthProvider.future,
        );
        if (cutoffMonth == null) return null;
        return ref
            .watch(projectionServiceProvider)
            .variation(
              byMonth: await ref.watch(complianceByMonthProvider.future),
              cutoffMonth: cutoffMonth,
              area: section.area,
              team: section.team,
            );
      },
    );

/// Per-category projection of an employee, for their detail screen. `null`
/// if they are not in the eligible payroll of the cutoff month.
final employeeProjectionProvider =
    FutureProvider.family<EmployeeProjection?, String>((ref, employeeId) async {
      final cutoffMonth = await ref.watch(
        annualProjectionCutoffMonthProvider.future,
      );
      if (cutoffMonth == null) return null;
      final byMonth = await ref.watch(complianceByMonthProvider.future);
      return ref
          .watch(projectionServiceProvider)
          .projectEmployee(
            own: byMonth.map(
              (month, items) => MapEntry(
                month,
                items
                    .where((item) => item.employee.employeeId == employeeId)
                    .toList(),
              ),
            ),
            cutoffMonth: cutoffMonth,
          );
    });

/// Projection of a section: `(area: null, team: null)` is the whole visible
/// payroll; with an area, only that area; with area and team, only that team.
final annualProjectionProvider =
    FutureProvider.family<AnnualProjection?, ({String? area, String? team})>((
      ref,
      section,
    ) async {
      final cutoffMonth = await ref.watch(
        annualProjectionCutoffMonthProvider.future,
      );
      if (cutoffMonth == null) return null;
      return ref
          .watch(projectionServiceProvider)
          .calculateForSection(
            byMonth: await ref.watch(complianceByMonthProvider.future),
            cutoffMonth: cutoffMonth,
            area: section.area,
            team: section.team,
          );
    });
