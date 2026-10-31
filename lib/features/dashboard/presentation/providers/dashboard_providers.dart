import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_labels.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/courses/presentation/providers/course_services_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_distribution.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_kpis_service.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_trend_service.dart';
import 'package:app_finnegans/features/dashboard/domain/monthly_hours.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/features/dashboard/domain/dashboard_distribution.dart';
export 'package:app_finnegans/features/dashboard/domain/monthly_hours.dart';

typedef DashboardKpiSummary = ({
  DashboardKpis kpis,
  int areaCount,
  int teamCount,
});

typedef DashboardDistribution = ({
  ComplianceDistribution compliance,
  CategoryDistribution categories,
});

typedef DashboardArea = ({AreaSummary area, int teamCount});

final dashboardKpisServiceProvider = Provider<DashboardKpisService>(
  (ref) => DashboardKpisService(
    classification: ref.watch(courseClassificationServiceProvider),
  ),
);

final dashboardTrendServiceProvider = Provider<DashboardTrendService>(
  (ref) => const DashboardTrendService(),
);

/// The hours are already in memory with the user's scope: changing the period
/// filters them, it does not query the database again.
final dashboardTimeEntriesProvider = FutureProvider<List<CrmTimeEntry>>((
  ref,
) async {
  final period = ref.watch(periodFilterProvider);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  return ref
      .watch(dashboardTrendServiceProvider)
      .timeEntriesInPeriod(timeEntries, period);
});

/// Same base as Teams and Areas, so the Dashboard KPIs match theirs.
final dashboardComplianceProvider = FutureProvider<List<EmployeeCompliance>>((
  ref,
) {
  return ref.watch(teamComplianceProvider.future);
});

final dashboardEvaluatedMonthsProvider = FutureProvider<int>((ref) async {
  final period = ref.watch(periodFilterProvider);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  return ref
      .watch(dashboardTrendServiceProvider)
      .evaluatedMonths(
        timeEntries: timeEntries,
        certifications: certifications,
        period: period,
      );
});

final dashboardMonthlyEvolutionProvider = FutureProvider<List<MonthlyHours>>((
  ref,
) async {
  final period = ref.watch(periodFilterProvider);
  final employees = await ref.watch(employeesProvider.future);
  final history = await ref.watch(employeeHistoryProvider.future);
  final courses = await ref.watch(coursesProvider.future);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  final userScope = await ref.watch(userScopeProvider.future);
  final complianceService = await ref.watch(complianceServiceProvider.future);
  return ref
      .watch(dashboardTrendServiceProvider)
      .monthlyEvolution(
        employees: employees,
        history: history,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        period: period,
        complianceService: complianceService,
        includeEmployee: ref
            .watch(userScopeServiceProvider)
            .employeeFilter(userScope),
      );
});

/// `null` when nobody is evaluated in the period.
final dashboardKpisProvider = FutureProvider<DashboardKpiSummary?>((ref) async {
  final compliance = await ref.watch(dashboardComplianceProvider.future);
  if (compliance.isEmpty) return null;
  final timeEntries = await ref.watch(dashboardTimeEntriesProvider.future);
  final evaluatedMonths = await ref.watch(
    dashboardEvaluatedMonthsProvider.future,
  );
  final areas = await ref.watch(areasPeriodSummaryProvider.future);
  final teams = await ref.watch(teamOverviewsProvider.future);
  return (
    kpis: ref
        .watch(dashboardKpisServiceProvider)
        .calculate(
          complianceList: compliance,
          timeEntries: timeEntries,
          evaluatedMonths: evaluatedMonths,
        ),
    areaCount: areas.areaCount,
    teamCount: teams.length,
  );
});

/// `null` when nobody is evaluated in the period.
final dashboardDistributionProvider = FutureProvider<DashboardDistribution?>((
  ref,
) async {
  final compliance = await ref.watch(dashboardComplianceProvider.future);
  if (compliance.isEmpty) return null;
  final service = ref.watch(dashboardKpisServiceProvider);
  return (
    compliance: service.complianceDistribution(compliance),
    categories: service.categoryDistribution(compliance),
  );
});

final dashboardAreasProvider = FutureProvider<List<DashboardArea>>((ref) async {
  final areas = await ref.watch(areasByComplianceProvider.future);
  final teams = await ref.watch(teamOverviewsProvider.future);
  final teamCount = ref.watch(areasServiceProvider).teamCountByArea(teams);
  return [
    for (final area in areas)
      (area: area, teamCount: teamCount[area.name] ?? 0),
  ];
});

FilterRow dashboardAreaFilterRow(AreaSummary area) =>
    FilterRow({'Área': area.name, 'Estado': area.level.label});

final dashboardAreaFilterRowsProvider = FutureProvider<List<FilterRow>>((
  ref,
) async {
  final areas = await ref.watch(areasByComplianceProvider.future);
  return areas.map(dashboardAreaFilterRow).toList();
});

/// The filter survives the period change that unmounts the section.
final filteredDashboardAreasProvider = FutureProvider<List<DashboardArea>>((
  ref,
) async {
  final selection = ref
      .watch(dataFilterSelectionProvider(DataFilterScope.dashboardAreas))
      .values;
  final filters = ref.watch(dataFilterServiceProvider);
  final areas = await ref.watch(dashboardAreasProvider.future);
  return areas
      .where(
        (item) => filters.matches(selection, dashboardAreaFilterRow(item.area)),
      )
      .toList();
});

final globalComplianceProvider = FutureProvider<List<EmployeeCompliance>>((
  ref,
) async {
  final employees = await ref.watch(employeesProvider.future);
  final courses = await ref.watch(coursesProvider.future);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  final service = await ref.watch(complianceServiceProvider.future);

  return service.calculateComplianceGlobal(
    employees: employees,
    courses: courses,
    timeEntries: timeEntries,
    lmsCertifications: certifications,
  );
});
