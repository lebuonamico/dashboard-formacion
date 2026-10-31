import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/areas/domain/area_summary.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:collection/collection.dart';

typedef AreaLeaderResolver = String? Function(String area);

class AreasService {
  final EmployeeLookupService lookup;
  final ComplianceLevelService levels;

  const AreasService({
    this.lookup = const EmployeeLookupService(),
    this.levels = const ComplianceLevelService(),
  });

  /// In the annual view an employee appears once per team: everything is
  /// counted by unique employee ID.
  AreaSummary summarize(
    String area,
    List<EmployeeCompliance> members, {
    String? leaders,
  }) {
    final employeeIds = members.map((m) => m.employee.employeeId).toSet();
    final pendingEmployeeIds = members
        .where((m) => !m.meetsTarget)
        .map((m) => m.employee.employeeId)
        .toSet();
    final completedHours = _sum(members, (m) => m.totalCreditedHours);
    final targetHours = _sum(members, (m) => m.totalRequiredHours);
    final percentage = targetHours == 0
        ? 100.0
        : completedHours / targetHours * 100;
    double categoryHours(CourseCategory category) =>
        _sum(members, (m) => m.applicableHours[category]!);

    return AreaSummary(
      name: area,
      generalTeams:
          members
              .map((member) => member.employee.team.trim())
              .where((team) => team.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
      memberCount: employeeIds.length,
      membersOnTarget: employeeIds.difference(pendingEmployeeIds).length,
      completedHours: completedHours,
      targetHours: targetHours,
      hoursDeviation: completedHours - targetHours,
      businessHours: categoryHours(CourseCategory.businessSkills),
      softSkillsHours: categoryHours(CourseCategory.softSkills),
      explorationHours: categoryHours(CourseCategory.exploration),
      teachingHours: categoryHours(CourseCategory.teaching),
      compliancePercentage: percentage,
      level: levels.fromPercentage(percentage),
      leaders: leaders,
    );
  }

  AreasPeriodSummary buildPeriodSummary(
    List<EmployeeCompliance> compliance, {
    AreaLeaderResolver? resolveLeaders,
  }) {
    final areas =
        groupBy(compliance, (EmployeeCompliance item) => item.employee.area)
            .entries
            .map(
              (entry) => summarize(
                entry.key,
                entry.value,
                leaders: resolveLeaders?.call(entry.key),
              ),
            )
            .toList()
          ..sort(_compareByPriority);
    double sum(double Function(AreaSummary area) hours) =>
        areas.fold(0.0, (total, area) => total + hours(area));
    int count(ComplianceLevel level) =>
        areas.where((area) => area.level == level).length;
    final completedHours = sum((area) => area.completedHours);
    final targetHours = sum((area) => area.targetHours);

    return AreasPeriodSummary(
      areas: areas,
      areaCount: areas.length,
      employeeCount: compliance
          .map((item) => item.employee.employeeId)
          .toSet()
          .length,
      completedHours: completedHours,
      targetHours: targetHours,
      hoursDeviation: completedHours - targetHours,
      overallCompletion: targetHours == 0
          ? 0
          : completedHours / targetHours * 100,
      businessHours: sum((area) => area.businessHours),
      softSkillsHours: sum((area) => area.softSkillsHours),
      explorationHours: sum((area) => area.explorationHours),
      teachingHours: sum((area) => area.teachingHours),
      onTarget: count(ComplianceLevel.onTarget),
      atRisk: count(ComplianceLevel.atRisk),
      critical: count(ComplianceLevel.critical),
    );
  }

  /// The area with its members sorted by name and the teams of the period
  /// that belong to it, or `null` if it has no eligible members.
  AreaDetail? getAreaDetail({
    required List<EmployeeCompliance> compliance,
    required List<TeamOverview> teams,
    required String area,
    AreaLeaderResolver? resolveLeaders,
  }) {
    final searched = normalizeLoose(area);
    final members =
        compliance
            .where((item) => normalizeLoose(item.employee.area) == searched)
            .toList()
          ..sort(
            (a, b) => lookup
                .fullName(a.employee)
                .compareTo(lookup.fullName(b.employee)),
          );
    if (members.isEmpty) return null;

    final name = members.first.employee.area;
    return AreaDetail(
      area: summarize(name, members, leaders: resolveLeaders?.call(name)),
      teams: teams
          .where((team) => normalizeLoose(team.area) == searched)
          .toList(),
      members: members,
    );
  }

  /// Highest compliance first, and by name on a tie.
  List<AreaSummary> byCompliance(List<AreaSummary> areas) => [...areas]
    ..sort((a, b) {
      final compliance = b.compliancePercentage.compareTo(
        a.compliancePercentage,
      );
      return compliance != 0 ? compliance : a.name.compareTo(b.name);
    });

  ComplianceLevel levelOf(EmployeeCompliance member) =>
      levels.fromPercentage(member.totalPercentage);

  Set<ComplianceLevel> levelsPresent(List<EmployeeCompliance> members) =>
      members.map(levelOf).toSet();

  /// An empty set of levels keeps every member.
  List<EmployeeCompliance> membersAtLevels(
    List<EmployeeCompliance> members,
    Set<ComplianceLevel> selected,
  ) => selected.isEmpty
      ? members
      : members.where((member) => selected.contains(levelOf(member))).toList();

  double _sum(
    List<EmployeeCompliance> members,
    double Function(EmployeeCompliance member) hours,
  ) => members.fold(0.0, (total, member) => total + hours(member));

  /// Worst first: critical, at risk and on target; then by ascending
  /// percentage and by name.
  int _compareByPriority(AreaSummary a, AreaSummary b) {
    final status = _levelOrder(a.level).compareTo(_levelOrder(b.level));
    if (status != 0) return status;
    final compliance = a.compliancePercentage.compareTo(b.compliancePercentage);
    if (compliance != 0) return compliance;
    return a.name.compareTo(b.name);
  }

  int _levelOrder(ComplianceLevel level) => switch (level) {
    ComplianceLevel.critical => 0,
    ComplianceLevel.atRisk => 1,
    ComplianceLevel.onTarget => 2,
  };
}
