import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/area_compliance_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';

/// Resumen de un área en el período, para las tarjetas de la pantalla Áreas.
class AreaGlobalViewModel {
  final String name;
  final List<String> generalTeams;
  final int memberCount;
  final int membersOnTarget;
  final double completedHours;
  final double targetHours;
  final double businessHours;
  final double softSkillsHours;
  final double explorationHours;
  final double teachingHours;
  final double compliancePercentage;

  /// El estado del área sólo mira el porcentaje de horas, igual que el
  /// Dashboard. No exige que todos los integrantes cumplan, como en Equipos.
  final ComplianceLevel level;

  /// Líderes de área asignados en el panel, o `null` si no tiene.
  final String? leaders;

  const AreaGlobalViewModel({
    required this.name,
    required this.generalTeams,
    required this.memberCount,
    required this.membersOnTarget,
    required this.completedHours,
    required this.targetHours,
    required this.businessHours,
    required this.softSkillsHours,
    required this.explorationHours,
    required this.teachingHours,
    required this.compliancePercentage,
    required this.level,
    this.leaders,
  });

  double get hoursDeviation => completedHours - targetHours;
}

/// Totales del período que consume la pantalla de Áreas.
class AreasPeriodSummary {
  final bool hasData;
  final List<AreaGlobalViewModel> areas;
  final int employees;
  final double completedHours;
  final double targetHours;
  final double businessHours;
  final double softSkillsHours;
  final double explorationHours;
  final double teachingHours;
  final int onTarget;
  final int atRisk;
  final int critical;

  const AreasPeriodSummary({
    this.hasData = true,
    required this.areas,
    required this.employees,
    required this.completedHours,
    required this.targetHours,
    required this.businessHours,
    required this.softSkillsHours,
    required this.explorationHours,
    required this.teachingHours,
    required this.onTarget,
    required this.atRisk,
    required this.critical,
  });

  const AreasPeriodSummary.noData()
    : this(
        hasData: false,
        areas: const [],
        employees: 0,
        completedHours: 0,
        targetHours: 0,
        businessHours: 0,
        softSkillsHours: 0,
        explorationHours: 0,
        teachingHours: 0,
        onTarget: 0,
        atRisk: 0,
        critical: 0,
      );

  int get totalAreas => areas.length;
  double get hoursDeviation => completedHours - targetHours;
  double get complianceGlobal =>
      targetHours == 0 ? 0 : completedHours / targetHours * 100;
}

final areasPeriodSummaryProvider = FutureProvider<AreasPeriodSummary>((
  ref,
) async {
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) {
    return const AreasPeriodSummary.noData();
  }
  // Mismo cálculo que Equipos: el período global y la nómina elegible.
  final complianceList = await ref.watch(teamComplianceProvider.future);
  final leaders = await ref.watch(leaderLabelsProvider.future);

  final grouped = <String, List<EmployeeCompliance>>{};
  for (final item in complianceList) {
    grouped.putIfAbsent(item.employee.area, () => []).add(item);
  }

  final areas = [
    for (final entry in grouped.entries)
      _summarizeArea(
        entry.key,
        entry.value,
        leaders: leaders.forArea(entry.key),
      ),
  ]..sort(_compareAreasByPriority);

  var completedHours = 0.0;
  var targetHours = 0.0;
  var businessHours = 0.0;
  var softSkillsHours = 0.0;
  var explorationHours = 0.0;
  var teachingHours = 0.0;
  for (final area in areas) {
    completedHours += area.completedHours;
    targetHours += area.targetHours;
    businessHours += area.businessHours;
    softSkillsHours += area.softSkillsHours;
    explorationHours += area.explorationHours;
    teachingHours += area.teachingHours;
  }

  return AreasPeriodSummary(
    areas: areas,
    // En el anual un legajo puede aparecer una vez por team: se cuenta una
    // sola vez.
    employees: complianceList
        .map((item) => item.employee.employeeId)
        .toSet()
        .length,
    completedHours: completedHours,
    targetHours: targetHours,
    businessHours: businessHours,
    softSkillsHours: softSkillsHours,
    explorationHours: explorationHours,
    teachingHours: teachingHours,
    onTarget: areas.where((a) => a.level == ComplianceLevel.onTarget).length,
    atRisk: areas.where((a) => a.level == ComplianceLevel.atRisk).length,
    critical: areas.where((a) => a.level == ComplianceLevel.critical).length,
  );
});

List<FilterRow> areaFilterRows(AreaGlobalViewModel area) => [
  for (final team in area.generalTeams.isEmpty ? [''] : area.generalTeams)
    FilterRow({'Área': area.name, 'Equipo': team, 'Estado': area.level.label}),
];

final areaFilterRowsProvider = FutureProvider<List<FilterRow>>((ref) async {
  final summary = await ref.watch(areasPeriodSummaryProvider.future);
  return summary.areas.expand(areaFilterRows).toList();
});

final filteredAreasProvider = FutureProvider<List<AreaGlobalViewModel>>((
  ref,
) async {
  final selection = ref
      .watch(dataFilterSelectionProvider(DataFilterScope.areas))
      .values;
  final filters = ref.watch(dataFilterServiceProvider);
  final summary = await ref.watch(areasPeriodSummaryProvider.future);
  return summary.areas
      .where(
        (area) =>
            areaFilterRows(area).any((row) => filters.matches(selection, row)),
      )
      .toList();
});

/// Área seleccionada junto con sus equipos y los integrantes evaluados en el
/// período.
class AreaDetailViewModel {
  final AreaGlobalViewModel area;
  final List<TeamOverview> teams;
  final List<EmployeeCompliance> members;

  const AreaDetailViewModel({
    required this.area,
    required this.teams,
    required this.members,
  });
}

/// Estados de la tabla de integrantes del detalle: `cumplido`, `riesgo`,
/// `critico`; conjunto vacío = todos. Se descarta al salir de la pantalla.
final areaMemberStatusFilterProvider = StateProvider.autoDispose<Set<String>>(
  (ref) => {},
);

final areaDetailProvider = FutureProvider.family<AreaDetailViewModel?, String>((
  ref,
  areaName,
) async {
  final complianceList = await ref.watch(teamComplianceProvider.future);
  final searched = areaName.trim().toLowerCase();

  final members =
      complianceList
          .where((item) => item.employee.area.trim().toLowerCase() == searched)
          .toList()
        ..sort((a, b) => a.employee.fullName.compareTo(b.employee.fullName));
  if (members.isEmpty) return null;

  // Los equipos salen del mismo cálculo que la pantalla de Equipos, así
  // las tarjetas muestran los mismos números en las dos pantallas.
  final teamsSummary = await ref.watch(teamsPeriodSummaryProvider.future);
  final teams = teamsSummary.teams
      .where((team) => team.area.trim().toLowerCase() == searched)
      .toList();

  final leaders = await ref.watch(leaderLabelsProvider.future);
  final name = members.first.employee.area;

  return AreaDetailViewModel(
    area: _summarizeArea(name, members, leaders: leaders.forArea(name)),
    teams: teams,
    members: members,
  );
});

AreaGlobalViewModel _summarizeArea(
  String area,
  List<EmployeeCompliance> members, {
  String? leaders,
}) {
  final employeeIds = members.map((m) => m.employee.employeeId).toSet();
  // Un legajo con alguna entrada pendiente no cuenta como en objetivo.
  final pendingEmployeeIds = members
      .where((m) => !m.meetsTarget)
      .map((m) => m.employee.employeeId)
      .toSet();
  final completedHours = members.fold<double>(
    0,
    (total, item) => total + item.totalCreditedHours,
  );
  final targetHours = members.fold<double>(
    0,
    (total, item) => total + item.totalRequiredHours,
  );
  final percentage = targetHours == 0
      ? 100.0
      : (completedHours / targetHours) * 100;
  final generalTeams =
      members
          .map((member) => member.employee.team.trim())
          .where((team) => team.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  return AreaGlobalViewModel(
    name: area,
    generalTeams: generalTeams,
    memberCount: employeeIds.length,
    membersOnTarget: employeeIds.difference(pendingEmployeeIds).length,
    completedHours: completedHours,
    targetHours: targetHours,
    businessHours: _sumCategoryHours(members, CourseCategory.businessSkills),
    softSkillsHours: _sumCategoryHours(members, CourseCategory.softSkills),
    explorationHours: _sumCategoryHours(members, CourseCategory.exploration),
    teachingHours: _sumCategoryHours(members, CourseCategory.teaching),
    compliancePercentage: percentage,
    level: ComplianceLevel.fromPercentage(percentage),
    leaders: leaders,
  );
}

double _sumCategoryHours(
  List<EmployeeCompliance> members,
  CourseCategory type,
) {
  return members.fold<double>(
    0,
    (total, member) => total + member.applicableHours(type),
  );
}

/// Lo que peor está, primero: críticas, en riesgo y en objetivo; dentro de
/// cada estado por porcentaje ascendente y después por nombre.
int _compareAreasByPriority(AreaGlobalViewModel a, AreaGlobalViewModel b) {
  final status = _levelOrder(a.level).compareTo(_levelOrder(b.level));
  if (status != 0) return status;

  final compliance = a.compliancePercentage.compareTo(b.compliancePercentage);
  if (compliance != 0) return compliance;

  return a.name.compareTo(b.name);
}

int _levelOrder(ComplianceLevel trafficLight) {
  switch (trafficLight) {
    case ComplianceLevel.critical:
      return 0;
    case ComplianceLevel.atRisk:
      return 1;
    case ComplianceLevel.onTarget:
      return 2;
  }
}
