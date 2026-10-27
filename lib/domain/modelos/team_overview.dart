import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';

part 'team_overview_compatibility.dart';

class TeamOverview {
  final String id;
  final String name;
  final String area;
  final String leader;
  final int memberCount;
  final int membersOnTarget;
  final double completedHours;
  final double targetHours;
  final double hoursDeviation;
  final double businessHours;
  final double softSkillsHours;
  final double explorationHours;
  final double teachingHours;
  final double averageHoursPerMember;
  final double completionPercentage;
  final TeamStatus status;

  const TeamOverview({
    required this.id,
    required this.name,
    required this.area,
    required this.leader,
    required this.memberCount,
    required this.membersOnTarget,
    required this.completedHours,
    required this.targetHours,
    required this.hoursDeviation,
    required this.businessHours,
    required this.softSkillsHours,
    required this.explorationHours,
    required this.teachingHours,
    required this.averageHoursPerMember,
    required this.completionPercentage,
    required this.status,
  });
}

class TeamsPeriodSummary {
  final bool hasData;
  final List<TeamOverview> teams;
  final int employeeCount;
  final double completedHours;
  final double targetHours;
  final double businessHours;
  final double softSkillsHours;
  final double explorationHours;
  final double teachingHours;
  final int onTarget;
  final int atRisk;
  final int critical;

  const TeamsPeriodSummary({
    this.hasData = true,
    required this.teams,
    required this.employeeCount,
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

  const TeamsPeriodSummary.noData()
    : this(
        hasData: false,
        teams: const [],
        employeeCount: 0,
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

  int get teamCount => teams.length;
  double get hoursDeviation => completedHours - targetHours;
  double get overallCompletion =>
      targetHours == 0 ? 0 : completedHours / targetHours * 100;
}

class TeamDetail {
  final TeamOverview overview;
  final List<CumplimientoEmpleado> members;

  const TeamDetail({required this.overview, required this.members});
}
