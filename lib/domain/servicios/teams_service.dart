import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_identity.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/team_period_service.dart';

typedef TeamLeaderResolver = String? Function(String area, String team);

class TeamsService {
  static const _onTargetPercentage = 100.0;
  static const _atRiskPercentage = 70.0;

  final TeamPeriodService periods;

  const TeamsService({this.periods = const TeamPeriodService()});

  List<TeamOverview> buildTeamOverviews(
    List<CumplimientoEmpleado> compliance, {
    TeamLeaderResolver? resolveLeader,
  }) {
    final membersByTeam = <String, List<CumplimientoEmpleado>>{};

    for (final item in compliance) {
      final employee = item.empleado;
      final teamName = normalizeTeamName(employee.equipo);
      final key = '${employee.area}::$teamName';

      membersByTeam.putIfAbsent(key, () => []).add(item);
    }

    final teams = <TeamOverview>[];
    for (final members in membersByTeam.values) {
      teams.add(_buildTeamOverview(members, resolveLeader));
    }

    teams.sort(_compareTeamsByPriority);
    return teams;
  }

  TeamDetail? getTeamDetail({
    required List<CumplimientoEmpleado> compliance,
    required String area,
    required String team,
    TeamLeaderResolver? resolveLeader,
  }) {
    final requestedArea = normalizeTeamComparison(area);
    final requestedTeam = normalizeTeamComparison(normalizeTeamName(team));
    final members = compliance.where((item) {
      final employee = item.empleado;
      return normalizeTeamComparison(employee.area) == requestedArea &&
          normalizeTeamComparison(normalizeTeamName(employee.equipo)) ==
              requestedTeam;
    }).toList();

    if (members.isEmpty) return null;

    final overview = _buildTeamOverview(members, resolveLeader);
    members.sort(
      (a, b) => a.empleado.nombreCompleto.compareTo(b.empleado.nombreCompleto),
    );

    return TeamDetail(overview: overview, members: members);
  }

  TeamsPeriodSummary buildPeriodSummary(
    List<CumplimientoEmpleado> compliance, {
    int? uniqueEmployeeCount,
    TeamLeaderResolver? resolveLeader,
  }) {
    final teams = buildTeamOverviews(compliance, resolveLeader: resolveLeader);
    var employeeCount = 0;
    var completedHours = 0.0;
    var targetHours = 0.0;
    var businessHours = 0.0;
    var softSkillsHours = 0.0;
    var explorationHours = 0.0;
    var teachingHours = 0.0;
    var onTarget = 0;
    var atRisk = 0;
    var critical = 0;

    for (final team in teams) {
      employeeCount += team.memberCount;
      completedHours += team.completedHours;
      targetHours += team.targetHours;
      businessHours += team.businessHours;
      softSkillsHours += team.softSkillsHours;
      explorationHours += team.explorationHours;
      teachingHours += team.teachingHours;
      switch (team.status) {
        case TeamStatus.onTarget:
          onTarget++;
          break;
        case TeamStatus.atRisk:
          atRisk++;
          break;
        case TeamStatus.critical:
          critical++;
          break;
      }
    }

    return TeamsPeriodSummary(
      teams: teams,
      employeeCount: uniqueEmployeeCount ?? employeeCount,
      completedHours: completedHours,
      targetHours: targetHours,
      businessHours: businessHours,
      softSkillsHours: softSkillsHours,
      explorationHours: explorationHours,
      teachingHours: teachingHours,
      onTarget: onTarget,
      atRisk: atRisk,
      critical: critical,
    );
  }

  TeamOverview _buildTeamOverview(
    List<CumplimientoEmpleado> members,
    TeamLeaderResolver? resolveLeader,
  ) {
    final firstEmployee = members.first.empleado;
    final teamName = normalizeTeamName(firstEmployee.equipo);
    // Assigned leaders take precedence over the manager from the employee roster.
    final assignedLeaders = resolveLeader?.call(firstEmployee.area, teamName);
    final completedHours = members.fold<double>(
      0,
      (total, member) => total + member.totalHorasValidas,
    );
    final targetHours = members.fold<double>(
      0,
      (total, member) => total + member.totalHorasRequeridas,
    );
    final completionPercentage = targetHours == 0
        ? 100.0
        : (completedHours / targetHours) * 100;
    final memberCount = members.length;
    final membersOnTarget = members
        .where((member) => member.cumpleObjetivo)
        .length;

    return TeamOverview(
      id: _createTeamId(firstEmployee.area, teamName),
      name: teamName,
      area: firstEmployee.area,
      leader: assignedLeaders != null && assignedLeaders.isNotEmpty
          ? assignedLeaders
          : firstEmployee.gerente.trim().isEmpty
          ? 'Sin líder asignado'
          : firstEmployee.gerente,
      memberCount: memberCount,
      membersOnTarget: membersOnTarget,
      completedHours: completedHours,
      targetHours: targetHours,
      hoursDeviation: completedHours - targetHours,
      businessHours: _sumCategoryHours(members, TipoCurso.habilidadesDeNegocio),
      softSkillsHours: _sumCategoryHours(members, TipoCurso.habilidadesBlandas),
      explorationHours: _sumCategoryHours(members, TipoCurso.libresExploracion),
      teachingHours: _sumCategoryHours(
        members,
        TipoCurso.dictadoCapacitaciones,
      ),
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

    if (completionPercentage >= _onTargetPercentage && allMembersOnTarget) {
      return TeamStatus.onTarget;
    }

    if (completionPercentage >= _atRiskPercentage || membersOnTarget > 0) {
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
    List<CumplimientoEmpleado> members,
    TipoCurso category,
  ) {
    return members.fold<double>(
      0,
      (total, member) => total + member.horasAplicablesAlObjetivo(category),
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
