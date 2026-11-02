import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';

class AreaSummary {
  final String name;
  final List<String> generalTeams;
  final int memberCount;
  final int membersOnTarget;
  final double completedHours;
  final double targetHours;
  final double hoursDeviation;
  final double businessHours;
  final double softSkillsHours;
  final double explorationHours;
  final double teachingHours;
  final double compliancePercentage;

  /// Only looks at the hours percentage, like the Dashboard. Unlike teams, it
  /// does not require every member to meet the target.
  final ComplianceLevel level;

  /// Area leaders assigned in the admin panel, or `null` without any.
  final String? leaders;

  const AreaSummary({
    required this.name,
    required this.generalTeams,
    required this.memberCount,
    required this.membersOnTarget,
    required this.completedHours,
    required this.targetHours,
    required this.hoursDeviation,
    required this.businessHours,
    required this.softSkillsHours,
    required this.explorationHours,
    required this.teachingHours,
    required this.compliancePercentage,
    required this.level,
    this.leaders,
  });
}

class AreasPeriodSummary {
  final bool hasData;
  final List<AreaSummary> areas;
  final int areaCount;
  final int employeeCount;
  final double completedHours;
  final double targetHours;
  final double hoursDeviation;
  final double overallCompletion;
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
    required this.areaCount,
    required this.employeeCount,
    required this.completedHours,
    required this.targetHours,
    required this.hoursDeviation,
    required this.overallCompletion,
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
        areaCount: 0,
        employeeCount: 0,
        completedHours: 0,
        targetHours: 0,
        hoursDeviation: 0,
        overallCompletion: 0,
        businessHours: 0,
        softSkillsHours: 0,
        explorationHours: 0,
        teachingHours: 0,
        onTarget: 0,
        atRisk: 0,
        critical: 0,
      );
}

class AreaDetail {
  final AreaSummary area;
  final List<TeamOverview> teams;
  final List<EmployeeCompliance> members;

  const AreaDetail({
    required this.area,
    required this.teams,
    required this.members,
  });
}
