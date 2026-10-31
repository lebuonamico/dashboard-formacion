import 'package:app_finnegans/features/compliance/domain/compliance_period_service.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';

class ProjectionService {
  static const onTrackPercentage = 100.0;
  static const reachablePercentage = 85.0;

  final CompliancePeriodService periods;

  const ProjectionService({this.periods = const CompliancePeriodService()});

  /// [percentage] is the part of the goal the projection covers.
  ProjectionStatus statusFor(double percentage) {
    if (percentage >= onTrackPercentage) return ProjectionStatus.onTrack;
    if (percentage >= reachablePercentage) return ProjectionStatus.reachable;
    return ProjectionStatus.atRisk;
  }

  /// Projection of a section: without [area] and [team] the whole visible
  /// payroll. The section is defined by where each employee is in the cutoff
  /// month; their whole year history counts, even from another team.
  AnnualProjection? calculateForSection({
    required Map<int, List<EmployeeCompliance>> byMonth,
    required int cutoffMonth,
    String? area,
    String? team,
  }) {
    if (area == null && team == null) {
      return calculate(byMonth: byMonth, cutoffMonth: cutoffMonth);
    }
    final employeeIds = (byMonth[cutoffMonth] ?? const <EmployeeCompliance>[])
        .where(
          (item) =>
              periods.belongsToTeam(item.employee, area: area, team: team),
        )
        .map((item) => item.employee.employeeId)
        .toSet();
    return calculate(
      byMonth: byMonth.map(
        (month, items) => MapEntry(
          month,
          items
              .where((item) => employeeIds.contains(item.employee.employeeId))
              .toList(),
        ),
      ),
      cutoffMonth: cutoffMonth,
    );
  }

  /// [byMonth] holds the monthly compliance of the months with data up to the
  /// cutoff; a month without anyone's data is absent and does not count. It
  /// projects the employees of the cutoff month with their whole year
  /// history. `null` when the cutoff month has no employees.
  AnnualProjection? calculate({
    required Map<int, List<EmployeeCompliance>> byMonth,
    required int cutoffMonth,
  }) {
    final previous = _previousMonth(byMonth, cutoffMonth);
    final preview = previous == null
        ? null
        : _calculate(byMonth: byMonth, cutoffMonth: previous);
    return _calculate(
      byMonth: byMonth,
      cutoffMonth: cutoffMonth,
      previousPercentage: preview?.percentage,
    );
  }

  /// One employee's projection, compared with the same projection cut at the
  /// previous month they were in. [own] holds only that employee.
  EmployeeProjection? projectEmployee({
    required Map<int, List<EmployeeCompliance>> own,
    required int cutoffMonth,
  }) {
    final current = projectEmployees(
      byMonth: own,
      cutoffMonth: cutoffMonth,
    ).firstOrNull;
    if (current == null) return null;
    final previous = _previousMonth(own, cutoffMonth);
    if (previous == null) return current;
    final preview = projectEmployees(
      byMonth: own,
      cutoffMonth: previous,
    ).firstOrNull;
    return employeeProjection(
      employeeId: current.employeeId,
      cutoffMonth: current.cutoffMonth,
      categories: current.categories,
      previousPercentage: preview?.percentage,
    );
  }

  /// Change of a section's compliance against the previous month. Each month
  /// is filtered by where each employee was that month and accumulated with
  /// the same calculation as the annual figure.
  ComplianceVariation? variation({
    required Map<int, List<EmployeeCompliance>> byMonth,
    required int cutoffMonth,
    String? area,
    String? team,
  }) {
    final all = area == null && team == null;
    final filtered = byMonth.map(
      (month, items) => MapEntry(
        month,
        all
            ? items
            : items
                  .where(
                    (item) => periods.belongsToTeam(
                      item.employee,
                      area: area,
                      team: team,
                    ),
                  )
                  .toList(),
      ),
    );

    double percentage(int until) {
      final accumulated = periods.accumulateMonths([
        for (final entry in filtered.entries)
          if (entry.key <= until) entry.value,
      ]);
      final hours = accumulated.fold<double>(
        0,
        (t, c) => t + c.totalCreditedHours,
      );
      final target = accumulated.fold<double>(
        0,
        (t, c) => t + c.totalRequiredHours,
      );
      return target == 0 ? 0 : hours / target * 100;
    }

    double? hoursPerPerson(int month) {
      final items = filtered[month];
      if (items == null || items.isEmpty) return null;
      return items.fold<double>(0, (t, c) => t + c.totalCreditedHours) /
          items.length;
    }

    final current = hoursPerPerson(cutoffMonth);
    if (current == null) return null;
    final previous = _previousMonth(filtered, cutoffMonth);
    final previousHours = hoursPerPerson(cutoffMonth - 1);
    return ComplianceVariation(
      points: previous == null
          ? null
          : percentage(cutoffMonth) - percentage(previous),
      hoursPerPerson: current,
      previousHoursPerPerson: previousHours,
      hours: previousHours == null ? null : current - previousHours,
    );
  }

  /// Projection of each employee of the cutoff month, per category, with
  /// their whole year history in [byMonth]. Only categories with a goal.
  List<EmployeeProjection> projectEmployees({
    required Map<int, List<EmployeeCompliance>> byMonth,
    required int cutoffMonth,
  }) {
    final history = <String, Map<int, EmployeeCompliance>>{};
    for (final MapEntry(key: month, value: items) in byMonth.entries) {
      if (month > cutoffMonth) continue;
      for (final item in items) {
        (history[item.employee.employeeId] ??= {})[month] = item;
      }
    }
    final remaining = 12 - cutoffMonth;
    final employeeIds = {
      for (final item in byMonth[cutoffMonth] ?? const <EmployeeCompliance>[])
        item.employee.employeeId,
    };

    return employeeIds.map((employeeId) {
      final months = history[employeeId]!;
      final cutoff = months[cutoffMonth]!;
      final categories = CourseCategory.values
          .map(
            (type) => _projectCategory(
              type: type,
              months: months,
              cutoff: cutoff,
              cutoffMonth: cutoffMonth,
              remaining: remaining,
            ),
          )
          .whereType<CategoryProjection>()
          .toList();
      return employeeProjection(
        employeeId: employeeId,
        cutoffMonth: cutoffMonth,
        categories: categories,
      );
    }).toList();
  }

  CategoryProjection? _projectCategory({
    required CourseCategory type,
    required Map<int, EmployeeCompliance> months,
    required EmployeeCompliance cutoff,
    required int cutoffMonth,
    required int remaining,
  }) {
    // Uncapped by month; only the months in which it was required count.
    final points = <({int month, double hours})>[
      for (final MapEntry(key: month, value: item) in months.entries)
        (
          month: month,
          hours: (item.requiredHours[type] ?? 0) > 0
              ? item.creditedHours[type] ?? 0
              : 0,
        ),
    ];
    final goal =
        months.values.fold<double>(
          0,
          (total, item) => total + (item.requiredHours[type] ?? 0),
        ) +
        (cutoff.requiredHours[type] ?? 0) * remaining;
    if (goal <= 0) return null;

    final accumulated = points.fold<double>(0, (t, p) => t + p.hours);
    final trend = _regression(points);
    final future = [
      for (var month = cutoffMonth + 1; month <= 12; month++) trend(month),
    ].where((estimated) => estimated > 0).fold(0.0, (t, e) => t + e);
    return categoryProjection(
      type: type,
      accumulated: accumulated,
      goal: goal,
      projected: accumulated + future,
    );
  }

  CategoryProjection categoryProjection({
    required CourseCategory type,
    required double accumulated,
    required double goal,
    required double projected,
  }) {
    final arrives = projected >= goal;
    return CategoryProjection(
      type: type,
      accumulated: accumulated,
      goal: goal,
      projected: projected,
      arrives: arrives,
      missing: arrives ? 0 : goal - projected,
    );
  }

  EmployeeProjection employeeProjection({
    required String employeeId,
    required int cutoffMonth,
    required List<CategoryProjection> categories,
    double? previousPercentage,
  }) {
    final projection = categories.fold<double>(
      0,
      (t, c) => t + (c.projected < c.goal ? c.projected : c.goal),
    );
    final goal = categories.fold<double>(0, (t, c) => t + c.goal);
    final percentage = goal == 0 ? 100.0 : projection / goal * 100;
    return EmployeeProjection(
      employeeId: employeeId,
      cutoffMonth: cutoffMonth,
      remainingMonths: 12 - cutoffMonth,
      categories: categories,
      projection: projection,
      goal: goal,
      percentage: percentage,
      status: statusFor(percentage),
      arrives: categories.every((c) => c.arrives),
      missing: categories.where((c) => !c.arrives).toList()
        ..sort((a, b) => b.missing.compareTo(a.missing)),
      previousPercentage: previousPercentage,
      variation: previousPercentage == null
          ? null
          : percentage - previousPercentage,
    );
  }

  AnnualProjection? _calculate({
    required Map<int, List<EmployeeCompliance>> byMonth,
    required int cutoffMonth,
    double? previousPercentage,
  }) {
    final atCutoff = byMonth[cutoffMonth] ?? const [];
    if (atCutoff.isEmpty) return null;

    final employees = projectEmployees(
      byMonth: byMonth,
      cutoffMonth: cutoffMonth,
    );
    final projection = employees.fold<double>(0, (t, e) => t + e.projection);
    final goal = employees.fold<double>(0, (t, e) => t + e.goal);
    final categories = employees.expand((e) => e.categories);
    final accumulated = categories.fold<double>(
      0,
      (t, c) => t + (c.accumulated < c.goal ? c.accumulated : c.goal),
    );
    final missing = categories.fold<double>(0, (t, c) => t + c.missing);

    final n = employees.length;
    double withCap(List<EmployeeCompliance> items) =>
        items.fold<double>(0, (t, c) => t + c.totalCreditedHours);
    final cutoffHours = withCap(atCutoff);
    final cutoffTarget = atCutoff.fold<double>(
      0,
      (t, c) => t + c.totalRequiredHours,
    );
    final previous = byMonth[cutoffMonth - 1] ?? const [];
    final remaining = 12 - cutoffMonth;
    final averageProjection = projection / n;
    final averageGoal = goal / n;
    final averageMissing = missing / n;
    final percentage = averageGoal == 0
        ? 100.0
        : averageProjection / averageGoal * 100;
    final recentPace = cutoffHours / n;
    final previousMonthPace = previous.isEmpty
        ? null
        : withCap(previous) / previous.length;

    return AnnualProjection(
      cutoffMonth: cutoffMonth,
      remainingMonths: remaining,
      employeeCount: n,
      arrive: employees.where((e) => e.arrives).length,
      projection: averageProjection,
      goal: averageGoal,
      accumulated: accumulated / n,
      missing: averageMissing,
      percentage: percentage,
      status: statusFor(goal == 0 ? 100 : projection / goal * 100),
      monthCompliance: cutoffTarget == 0
          ? 100
          : cutoffHours / cutoffTarget * 100,
      recentPace: recentPace,
      previousMonthPace: previousMonthPace,
      variation: previousMonthPace == null
          ? null
          : recentPace - previousMonthPace,
      previousPercentage: previousPercentage,
      projectionVariation: previousPercentage == null
          ? null
          : percentage - previousPercentage,
      adjustment: remaining == 0 ? 0 : averageMissing / remaining,
    );
  }

  /// The month with data before [cutoffMonth], or `null`.
  static int? _previousMonth(
    Map<int, List<EmployeeCompliance>> byMonth,
    int cutoffMonth,
  ) {
    final months =
        byMonth.entries
            .where((e) => e.key < cutoffMonth && e.value.isNotEmpty)
            .map((e) => e.key)
            .toList()
          ..sort();
    return months.lastOrNull;
  }

  /// Simple linear regression of hours over the month. With a single month
  /// the trend is flat.
  double Function(int month) _regression(
    List<({int month, double hours})> points,
  ) {
    final n = points.length;
    final meanX = points.fold<double>(0, (t, p) => t + p.month) / n;
    final meanY = points.fold<double>(0, (t, p) => t + p.hours) / n;
    final covariance = points.fold<double>(
      0,
      (t, p) => t + (p.month - meanX) * (p.hours - meanY),
    );
    final variance = points.fold<double>(
      0,
      (t, p) => t + (p.month - meanX) * (p.month - meanX),
    );
    final slope = variance == 0 ? 0.0 : covariance / variance;
    final intercept = meanY - slope * meanX;
    return (month) => intercept + slope * month;
  }
}
