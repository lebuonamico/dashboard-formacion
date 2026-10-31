import 'package:collection/collection.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/teams/domain/team_identity.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_period_service.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';

typedef TeamLeaderResolver = String? Function(String area, String team);

class TeamsService {
  final CompliancePeriodService periods;
  final EmployeeLookupService lookup;

  const TeamsService({
    this.periods = const CompliancePeriodService(),
    this.lookup = const EmployeeLookupService(),
  });

  List<TeamOverview> buildTeamOverviews(
    List<EmployeeCompliance> compliance, {
    TeamLeaderResolver? resolveLeader,
  }) {
    final membersByTeam = groupBy(
      compliance,
      (EmployeeCompliance item) =>
          '${item.employee.area}::${normalizeTeamName(item.employee.team)}',
    );
    return membersByTeam.values
        .map((members) => _buildTeamOverview(members, resolveLeader))
        .toList()
      ..sort(_compareTeamsByPriority);
  }

  TeamDetail? getTeamDetail({
    required List<EmployeeCompliance> compliance,
    required String area,
    required String team,
    TeamLeaderResolver? resolveLeader,
  }) {
    final requestedArea = normalizeLoose(area);
    final requestedTeam = normalizeLoose(normalizeTeamName(team));
    final members = compliance.where((item) {
      final employee = item.employee;
      return normalizeLoose(employee.area) == requestedArea &&
          normalizeLoose(normalizeTeamName(employee.team)) == requestedTeam;
    }).toList();

    if (members.isEmpty) return null;

    final overview = _buildTeamOverview(members, resolveLeader);
    members.sort(
      (a, b) =>
          lookup.fullName(a.employee).compareTo(lookup.fullName(b.employee)),
    );

    return TeamDetail(overview: overview, members: members);
  }

  TeamsPeriodSummary buildPeriodSummary(
    List<EmployeeCompliance> compliance, {
    int? uniqueEmployeeCount,
    TeamLeaderResolver? resolveLeader,
  }) {
    final teams = buildTeamOverviews(compliance, resolveLeader: resolveLeader);
    double sum(double Function(TeamOverview team) hours) =>
        teams.fold(0.0, (total, team) => total + hours(team));
    int count(TeamStatus status) =>
        teams.where((team) => team.status == status).length;

    final completedHours = sum((team) => team.completedHours);
    final targetHours = sum((team) => team.targetHours);

    return TeamsPeriodSummary(
      teams: teams,
      teamCount: teams.length,
      employeeCount:
          uniqueEmployeeCount ??
          teams.fold(0, (total, team) => total + team.memberCount),
      completedHours: completedHours,
      targetHours: targetHours,
      hoursDeviation: completedHours - targetHours,
      overallCompletion: targetHours == 0
          ? 0
          : completedHours / targetHours * 100,
      businessHours: sum((team) => team.businessHours),
      softSkillsHours: sum((team) => team.softSkillsHours),
      explorationHours: sum((team) => team.explorationHours),
      teachingHours: sum((team) => team.teachingHours),
      onTarget: count(TeamStatus.onTarget),
      atRisk: count(TeamStatus.atRisk),
      critical: count(TeamStatus.critical),
    );
  }

  TeamOverview _buildTeamOverview(
    List<EmployeeCompliance> members,
    TeamLeaderResolver? resolveLeader,
  ) {
    final firstEmployee = members.first.employee;
    final teamName = normalizeTeamName(firstEmployee.team);
    // Assigned leaders take precedence over the manager from the employee roster.
    final assignedLeaders = resolveLeader?.call(firstEmployee.area, teamName);
    final completedHours = members.fold<double>(
      0,
      (total, member) => total + member.totalCreditedHours,
    );
    final targetHours = members.fold<double>(
      0,
      (total, member) => total + member.totalRequiredHours,
    );
    final completionPercentage = targetHours == 0
        ? 100.0
        : (completedHours / targetHours) * 100;
    final memberCount = members.length;
    final membersOnTarget = members
        .where((member) => member.meetsTarget)
        .length;

    return TeamOverview(
      id: _createTeamId(firstEmployee.area, teamName),
      name: teamName,
      area: firstEmployee.area,
      leader: assignedLeaders != null && assignedLeaders.isNotEmpty
          ? assignedLeaders
          : firstEmployee.manager.trim().isEmpty
          ? 'Sin líder asignado'
          : firstEmployee.manager,
      memberCount: memberCount,
      membersOnTarget: membersOnTarget,
      completedHours: completedHours,
      targetHours: targetHours,
      hoursDeviation: completedHours - targetHours,
      businessHours: _sumCategoryHours(members, CourseCategory.businessSkills),
      softSkillsHours: _sumCategoryHours(members, CourseCategory.softSkills),
      explorationHours: _sumCategoryHours(members, CourseCategory.exploration),
      teachingHours: _sumCategoryHours(members, CourseCategory.teaching),
      averageHoursPerMember: memberCount == 0
          ? 0
          : completedHours / memberCount,
      completionPercentage: completionPercentage,
      status: calculateTeamStatus(
        completionPercentage: completionPercentage,
        memberCount: memberCount,
        membersOnTarget: membersOnTarget,
      ),
    );
  }

  TeamStatus calculateTeamStatus({
    required double completionPercentage,
    required int memberCount,
    required int membersOnTarget,
  }) {
    final allMembersOnTarget =
        memberCount > 0 && membersOnTarget == memberCount;

    if (completionPercentage >= ComplianceLevelService.onTargetPercentage &&
        allMembersOnTarget) {
      return TeamStatus.onTarget;
    }

    if (completionPercentage >= ComplianceLevelService.atRiskPercentage ||
        membersOnTarget > 0) {
      return TeamStatus.atRisk;
    }

    return TeamStatus.critical;
  }

  int _compareTeamsByPriority(TeamOverview a, TeamOverview b) {
    final statusOrder = _statusPriority(
      a.status,
    ).compareTo(_statusPriority(b.status));
    if (statusOrder != 0) return statusOrder;

    final completionOrder = a.completionPercentage.compareTo(
      b.completionPercentage,
    );
    if (completionOrder != 0) return completionOrder;

    return a.name.compareTo(b.name);
  }

  int _statusPriority(TeamStatus status) {
    switch (status) {
      case TeamStatus.critical:
        return 0;
      case TeamStatus.atRisk:
        return 1;
      case TeamStatus.onTarget:
        return 2;
    }
  }

  double _sumCategoryHours(
    List<EmployeeCompliance> members,
    CourseCategory category,
  ) {
    return members.fold<double>(
      0,
      (total, member) => total + member.applicableHours[category]!,
    );
  }

  String _createTeamId(String area, String team) {
    return '${_normalizeId(area)}-${_normalizeId(team)}';
  }

  String _normalizeId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
