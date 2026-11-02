import 'package:app_finnegans/features/courses/domain/course_category.dart';

/// How many evaluated employees fall into each compliance level.
class ComplianceDistribution {
  final int total;
  final int onTarget;
  final int atRisk;
  final int critical;

  /// Share of employees on target, between 0 and 1.
  final double onTargetShare;

  const ComplianceDistribution({
    required this.total,
    required this.onTarget,
    required this.atRisk,
    required this.critical,
    required this.onTargetShare,
  });
}

/// Hours that count towards the target, by category and per person.
class CategoryDistribution {
  final Map<CourseCategory, double> hours;
  final double totalHours;
  final double averageHours;
  final double averageTarget;
  final double totalTarget;

  const CategoryDistribution({
    required this.hours,
    required this.totalHours,
    required this.averageHours,
    required this.averageTarget,
    required this.totalTarget,
  });
}
