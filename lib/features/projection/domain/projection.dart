import 'package:app_finnegans/features/courses/domain/course_category.dart';

/// Whether, with each employee's trend, the year-end goal is reached.
enum ProjectionStatus { onTrack, reachable, atRisk }

/// Projection of one category for one employee, in hours.
class CategoryProjection {
  final CourseCategory type;

  /// Uncapped hours of the months with data up to the cutoff.
  final double accumulated;

  /// Target of the months with data up to the cutoff plus the remaining ones.
  final double goal;

  /// Accumulated plus what the trend estimates for the remaining months.
  final double projected;

  final bool arrives;

  /// Hours missing at year end with the current trend.
  final double missing;

  const CategoryProjection({
    required this.type,
    required this.accumulated,
    required this.goal,
    required this.projected,
    required this.arrives,
    required this.missing,
  });
}

/// Year-end projection of one employee, only with the categories their
/// seniority requires.
class EmployeeProjection {
  final String employeeId;
  final int cutoffMonth;
  final int remainingMonths;
  final List<CategoryProjection> categories;

  /// Projected hours, each category capped at its goal.
  final double projection;
  final double goal;
  final double percentage;
  final ProjectionStatus status;

  /// Meets every category.
  final bool arrives;

  /// Categories that do not arrive, the one missing the most first.
  final List<CategoryProjection> missing;

  /// [percentage] of the projection cut at the previous month with data;
  /// `null` when there is none.
  final double? previousPercentage;

  /// Goal points gained (or lost) against the previous month.
  final double? variation;

  const EmployeeProjection({
    required this.employeeId,
    required this.cutoffMonth,
    required this.remainingMonths,
    required this.categories,
    required this.projection,
    required this.goal,
    required this.percentage,
    required this.status,
    required this.arrives,
    required this.missing,
    required this.previousPercentage,
    required this.variation,
  });
}

/// Year-end projection of a section, cut at [cutoffMonth]. Calculated per
/// employee and category and then grouped: one person's hours never cover
/// what another one lacks, nor one category another. Hours are averages per
/// person.
class AnnualProjection {
  final int cutoffMonth;
  final int remainingMonths;
  final int employeeCount;

  /// Employees who, with their trend, meet every category.
  final int arrive;

  /// Hours projected to December, each capped at its category goal.
  final double projection;

  /// Target of the months with data up to the cutoff plus the remaining ones.
  final double goal;

  /// Hours accumulated up to the cutoff, capped at their category goal.
  final double accumulated;

  /// Hours that the ones who do not arrive still lack with their trend.
  final double missing;

  final double percentage;
  final ProjectionStatus status;

  /// Compliance of the cutoff month, with the monthly cap.
  final double monthCompliance;

  /// Hours of the cutoff month with the monthly cap.
  final double recentPace;

  /// Hours of the month before the cutoff; `null` without data.
  final double? previousMonthPace;

  /// Difference of hours per person against the previous month.
  final double? variation;

  /// [percentage] of the projection cut at the previous month with data.
  final double? previousPercentage;

  /// Goal points the projection gained (or lost) against the previous one.
  final double? projectionVariation;

  /// Hours per person and month to add to the trend to arrive; 0 when no
  /// months remain.
  final double adjustment;

  const AnnualProjection({
    required this.cutoffMonth,
    required this.remainingMonths,
    required this.employeeCount,
    required this.arrive,
    required this.projection,
    required this.goal,
    required this.accumulated,
    required this.missing,
    required this.percentage,
    required this.status,
    required this.monthCompliance,
    required this.recentPace,
    required this.previousMonthPace,
    required this.variation,
    required this.previousPercentage,
    required this.projectionVariation,
    required this.adjustment,
  });
}

/// How a section's compliance changed against the previous month.
class ComplianceVariation {
  /// Annual: points the year accumulated gained or lost against the
  /// accumulated up to the previous month with data. `null` without one.
  final double? points;

  /// Monthly: hours per person of the cutoff month, with the monthly cap.
  final double hoursPerPerson;

  /// Hours per person of the previous month; `null` without data.
  final double? previousHoursPerPerson;

  /// [hoursPerPerson] minus [previousHoursPerPerson].
  final double? hours;

  const ComplianceVariation({
    required this.points,
    required this.hoursPerPerson,
    required this.previousHoursPerPerson,
    required this.hours,
  });
}
