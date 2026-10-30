import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:app_finnegans/domain/servicios/teams_service.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/providers/period_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

export 'package:app_finnegans/domain/modelos/team_overview.dart';
export 'package:app_finnegans/domain/modelos/team_status.dart';
export 'package:app_finnegans/presentation/providers/period_providers.dart';

const teamFilterScope = 'equipos';

final teamSearchQueryProvider = StateProvider<String>((ref) => '');
final teamStatusFilterProvider = StateProvider<TeamStatus?>((ref) => null);

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
  final scope = ref.watch(periodScopeProvider);
  final month = ref.watch(periodMonthFilterProvider);
  final year = ref.watch(periodYearFilterProvider);
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
  final scope = ref.watch(periodScopeProvider);
  final month = ref.watch(periodMonthFilterProvider);
  final year = ref.watch(periodYearFilterProvider);
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
      ref.watch(periodScopeProvider) == PeriodScope.annual
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

final filteredTeamOverviewsProvider = Provider<AsyncValue<List<TeamOverview>>>((
  ref,
) {
  final selectedStatus = ref.watch(teamStatusFilterProvider);
  final selection = ref.watch(dataFilterSelectionProvider(teamFilterScope));
  final summaryAsync = ref.watch(teamsPeriodSummaryProvider);
  final query = ref.watch(teamSearchQueryProvider).trim().toLowerCase();

  return summaryAsync.whenData((summary) {
    return summary.teams.where((team) {
      final matchesQuery =
          query.isEmpty ||
          team.name.toLowerCase().contains(query) ||
          team.area.toLowerCase().contains(query) ||
          team.leader.toLowerCase().contains(query);
      final matchesStatus =
          selectedStatus == null || team.status == selectedStatus;
      return matchesQuery &&
          matchesStatus &&
          matchesDataFilters(selection, teamFilterRow(team));
    }).toList();
  });
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
