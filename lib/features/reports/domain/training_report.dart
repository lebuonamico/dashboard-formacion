import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/moodle_crm_comparison.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/dashboard/domain/monthly_hours.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';

/// Which section of the app the report summarizes.
enum ReportType { general, area, team }

/// Traffic light of a report row, already resolved by the builder.
enum ReportLevel { ok, attention, critical }

/// What location data goes with each member in the table.
enum MemberLocation { none, team, teamAreaY }

typedef ReportCategoryHours = ({
  CourseCategory category,
  double credited,
  double target,
});

/// A breakdown row: areas in the general report, teams in the area one.
class ReportBreakdownRow {
  final String name;
  final int memberCount;
  final double hours;
  final double target;
  final double percentage;
  final ReportLevel level;

  const ReportBreakdownRow({
    required this.name,
    required this.memberCount,
    required this.hours,
    required this.target,
    required this.percentage,
    required this.level,
  });
}

/// Everything the report shows, with the same numbers as the screen.
class TrainingReport {
  final ReportType type;
  final String title;
  final String period;

  final int memberCount;
  final int onTarget;
  final double hours;
  final double target;
  final double percentage;
  final ReportLevel level;

  /// Data for the lines under the title; each type uses its own.
  final String? area;
  final String? leaders;
  final int? areaCount;
  final int? teamCount;
  final int? trainingCount;

  final AnnualProjection? projection;
  final List<EmployeeCompliance> members;

  /// Lowest compliance first.
  final List<ReportBreakdownRow> breakdown;

  /// Credited hours per person in the last months (general report only).
  final List<MonthlyHours> evolution;

  /// The general report has a long payroll: it only lists the critical ones.
  final bool criticalOnly;
  final MemberLocation memberLocation;
  final Map<ReportLevel, int> countByLevel;
  final List<ReportCategoryHours> hoursByCategory;
  final MoodleCrmComparison sourceComparison;

  /// Lowest compliance first, by name on a tie.
  final List<EmployeeCompliance> listedMembers;

  const TrainingReport({
    required this.type,
    required this.title,
    required this.period,
    required this.memberCount,
    required this.onTarget,
    required this.hours,
    required this.target,
    required this.percentage,
    required this.level,
    this.area,
    this.leaders,
    this.areaCount,
    this.teamCount,
    this.trainingCount,
    this.projection,
    required this.members,
    required this.breakdown,
    required this.evolution,
    required this.criticalOnly,
    required this.memberLocation,
    required this.countByLevel,
    required this.hoursByCategory,
    required this.sourceComparison,
    required this.listedMembers,
  });
}
