import 'package:app_finnegans/features/areas/domain/area_summary.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/moodle_crm_comparison_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_kpis_service.dart';
import 'package:app_finnegans/features/dashboard/domain/monthly_hours.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';

/// Builds each screen's report from the same calculations as its cards.
class TrainingReportBuilder {
  final ComplianceLevelService levels;
  final MoodleCrmComparisonService comparison;
  final EmployeeLookupService lookup;

  const TrainingReportBuilder({
    this.levels = const ComplianceLevelService(),
    this.comparison = const MoodleCrmComparisonService(),
    this.lookup = const EmployeeLookupService(),
  });

  /// Same cut points as the app's traffic light.
  ReportLevel levelFor(double percentage) =>
      _fromComplianceLevel(levels.fromPercentage(percentage));

  /// A team also needs every member on target to be on target.
  ReportLevel levelForTeam(TeamStatus status) => switch (status) {
    TeamStatus.onTarget => ReportLevel.ok,
    TeamStatus.atRisk => ReportLevel.attention,
    TeamStatus.critical => ReportLevel.critical,
  };

  TrainingReport general({
    required String title,
    required String period,
    required DashboardKpis kpis,
    required int areaCount,
    required int teamCount,
    required List<AreaSummary> areas,
    required List<EmployeeCompliance> members,
    AnnualProjection? projection,
    List<MonthlyHours> evolution = const [],
  }) => build(
    type: ReportType.general,
    title: title,
    period: period,
    memberCount: kpis.employees,
    // In the annual view an employee who changed teams appears once per stage.
    onTarget: members
        .where((member) => member.meetsTarget)
        .map((member) => member.employee.employeeId)
        .toSet()
        .length,
    hours: kpis.creditedHours,
    target: kpis.targetHours,
    percentage: kpis.compliance,
    level: levelFor(kpis.compliance),
    areaCount: areaCount,
    teamCount: teamCount,
    trainingCount: kpis.training,
    projection: projection,
    members: members,
    breakdown: areas
        .map(
          (area) => ReportBreakdownRow(
            name: area.name,
            memberCount: area.memberCount,
            hours: area.completedHours,
            target: area.targetHours,
            percentage: area.compliancePercentage,
            level: _fromComplianceLevel(area.level),
          ),
        )
        .toList(),
    evolution: evolution,
  );

  TrainingReport area({
    required String period,
    required AreaDetail detail,
    AnnualProjection? projection,
  }) {
    final area = detail.area;
    return build(
      type: ReportType.area,
      title: area.name,
      period: period,
      memberCount: area.memberCount,
      onTarget: area.membersOnTarget,
      hours: area.completedHours,
      target: area.targetHours,
      percentage: area.compliancePercentage,
      level: _fromComplianceLevel(area.level),
      leaders: area.leaders,
      teamCount: detail.teams.length,
      projection: projection,
      members: detail.members,
      breakdown: detail.teams.map(_teamRow).toList(),
    );
  }

  TrainingReport team({
    required String period,
    required TeamDetail detail,
    AnnualProjection? projection,
  }) {
    final team = detail.overview;
    return build(
      type: ReportType.team,
      title: team.name,
      period: period,
      memberCount: team.memberCount,
      onTarget: team.membersOnTarget,
      hours: team.completedHours,
      target: team.targetHours,
      percentage: team.completionPercentage,
      level: levelForTeam(team.status),
      area: team.area,
      leaders: team.leader,
      projection: projection,
      members: detail.members,
    );
  }

  /// Fills in the fields every report derives from its members and type.
  TrainingReport build({
    required ReportType type,
    required String title,
    required String period,
    required int memberCount,
    required int onTarget,
    required double hours,
    required double target,
    required double percentage,
    required ReportLevel level,
    String? area,
    String? leaders,
    int? areaCount,
    int? teamCount,
    int? trainingCount,
    AnnualProjection? projection,
    required List<EmployeeCompliance> members,
    List<ReportBreakdownRow> breakdown = const [],
    List<MonthlyHours> evolution = const [],
  }) {
    final criticalOnly = type == ReportType.general;
    return TrainingReport(
      type: type,
      title: title,
      period: period,
      memberCount: memberCount,
      onTarget: onTarget,
      hours: hours,
      target: target,
      percentage: percentage,
      level: level,
      area: area,
      leaders: leaders,
      areaCount: areaCount,
      teamCount: teamCount,
      trainingCount: trainingCount,
      projection: projection,
      members: members,
      breakdown: [...breakdown]
        ..sort((a, b) => a.percentage.compareTo(b.percentage)),
      evolution: evolution,
      criticalOnly: criticalOnly,
      memberLocation: switch (type) {
        ReportType.general => MemberLocation.teamAreaY,
        ReportType.area => MemberLocation.team,
        ReportType.team => MemberLocation.none,
      },
      countByLevel: _countByLevel(members),
      hoursByCategory: _hoursByCategory(members),
      sourceComparison: comparison.compare(members),
      listedMembers: _listedMembers(members, criticalOnly: criticalOnly),
    );
  }

  ReportBreakdownRow _teamRow(TeamOverview team) => ReportBreakdownRow(
    name: team.name,
    memberCount: team.memberCount,
    hours: team.completedHours,
    target: team.targetHours,
    percentage: team.completionPercentage,
    level: levelForTeam(team.status),
  );

  ReportLevel _fromComplianceLevel(ComplianceLevel level) => switch (level) {
    ComplianceLevel.onTarget => ReportLevel.ok,
    ComplianceLevel.atRisk => ReportLevel.attention,
    ComplianceLevel.critical => ReportLevel.critical,
  };

  /// Every level is present, even with no members.
  Map<ReportLevel, int> _countByLevel(List<EmployeeCompliance> members) {
    final levels = members.map((m) => levelFor(m.totalPercentage)).toList();
    return {
      for (final level in ReportLevel.values)
        level: levels.where((current) => current == level).length,
    };
  }

  /// Each person adds up to their target in each category, and nothing in
  /// the ones their seniority does not ask for.
  List<ReportCategoryHours> _hoursByCategory(List<EmployeeCompliance> members) {
    double sum(double Function(EmployeeCompliance member) value) =>
        members.fold(0.0, (total, member) => total + value(member));
    return CourseCategory.values
        .map(
          (category) => (
            category: category,
            credited: sum((m) => m.applicableHours[category]!),
            target: sum((m) => m.requiredHours[category] ?? 0),
          ),
        )
        .toList();
  }

  List<EmployeeCompliance> _listedMembers(
    List<EmployeeCompliance> members, {
    required bool criticalOnly,
  }) {
    final sorted = [...members]
      ..sort((a, b) {
        final percentage = a.totalPercentage.compareTo(b.totalPercentage);
        return percentage != 0
            ? percentage
            : lookup
                  .fullName(a.employee)
                  .compareTo(lookup.fullName(b.employee));
      });
    return criticalOnly
        ? sorted
              .where((m) => levelFor(m.totalPercentage) == ReportLevel.critical)
              .toList()
        : sorted;
  }
}
