import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/teams_service.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/features/teams/domain/team_overview.dart';
export 'package:app_finnegans/features/teams/domain/team_status.dart';
export 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';

final teamsServiceProvider = Provider<TeamsService>(
  (ref) => const TeamsService(),
);

final availableTeamYearsProvider = FutureProvider<List<int>>((ref) async {
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  final years = timeEntries.map((entry) => entry.date.year).toSet()
    ..addAll(
      certifications
          .map((certification) => certification.completedAt?.year)
          .whereType<int>(),
    )
    ..add(DateTime.now().year);
  return years.toList()..sort((a, b) => b.compareTo(a));
});

final hasTeamPeriodDataProvider = FutureProvider<bool>((ref) async {
  final scope = ref.watch(periodFilterProvider).scope;
  final month = ref.watch(periodFilterProvider).month;
  final year = ref.watch(periodFilterProvider).year;
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  return ref
      .read(teamsServiceProvider)
      .periods
      .hasDataInPeriod(
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
        month: month,
        isAnnual: scope == PeriodScope.annual,
      );
});

final teamComplianceProvider = FutureProvider<List<EmployeeCompliance>>((
  ref,
) async {
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) return [];

  final employees = await ref.watch(employeesProvider.future);
  final history = await ref.watch(employeeHistoryProvider.future);
  final courses = await ref.watch(coursesProvider.future);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  final scope = ref.watch(periodFilterProvider).scope;
  final month = ref.watch(periodFilterProvider).month;
  final year = ref.watch(periodFilterProvider).year;
  final complianceService = await ref.watch(complianceServiceProvider.future);
  final periodService = ref.read(teamsServiceProvider).periods;
  final userScope = await ref.watch(userScopeProvider.future);

  // Apply permissions to each month's historical team rather than the current team.
  final includeEmployee = userScope.isTotal ? null : userScope.includesEmployee;

  if (scope == PeriodScope.annual) {
    return periodService.calculateAnnualCompliance(
      employees: employees,
      history: history,
      courses: courses,
      timeEntries: timeEntries,
      certifications: certifications,
      year: year,
      complianceService: complianceService,
      includeEmployee: includeEmployee,
    );
  }

  return periodService.calculateMonthlyCompliance(
    employees: employees,
    history: history,
    courses: courses,
    timeEntries: timeEntries,
    certifications: certifications,
    year: year,
    month: month,
    complianceService: complianceService,
    includeEmployee: includeEmployee,
  );
});

final teamsPeriodSummaryProvider = FutureProvider<TeamsPeriodSummary>((
  ref,
) async {
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) {
    return const TeamsPeriodSummary.noData();
  }
  final compliance = await ref.watch(teamComplianceProvider.future);
  final service = ref.read(teamsServiceProvider);
  final leaders = await ref.watch(leaderLabelsProvider.future);
  final uniqueEmployeeCount =
      ref.watch(periodFilterProvider).scope == PeriodScope.annual
      ? compliance.map((item) => item.employee.employeeId).toSet().length
      : null;
  return service.buildPeriodSummary(
    compliance,
    uniqueEmployeeCount: uniqueEmployeeCount,
    resolveLeader: leaders?.forTeam,
  );
});

final teamOverviewsProvider = FutureProvider<List<TeamOverview>>((ref) async {
  final summary = await ref.watch(teamsPeriodSummaryProvider.future);
  return summary.teams;
});

FilterRow teamFilterRow(TeamOverview team) => FilterRow({
  'Equipo': team.name,
  'Área': team.area,
  'Líder': team.leader,
  'Estado': team.status.label,
});

final teamFilterRowsProvider = FutureProvider<List<FilterRow>>((ref) async {
  final summary = await ref.watch(teamsPeriodSummaryProvider.future);
  return summary.teams.map(teamFilterRow).toList();
});

final filteredTeamOverviewsProvider = FutureProvider<List<TeamOverview>>((
  ref,
) async {
  final selection = ref
      .watch(dataFilterSelectionProvider(DataFilterScope.teams))
      .values;
  final filters = ref.watch(dataFilterServiceProvider);
  final summary = await ref.watch(teamsPeriodSummaryProvider.future);
  return summary.teams
      .where((team) => filters.matches(selection, teamFilterRow(team)))
      .toList();
});

final teamDetailProvider =
    FutureProvider.family<TeamDetail?, ({String area, String team})>((
      ref,
      selection,
    ) async {
      final compliance = await ref.watch(teamComplianceProvider.future);
      final service = ref.read(teamsServiceProvider);
      final leaders = await ref.watch(leaderLabelsProvider.future);
      return service.getTeamDetail(
        compliance: compliance,
        area: selection.area,
        team: selection.team,
        resolveLeader: leaders?.forTeam,
      );
    });
