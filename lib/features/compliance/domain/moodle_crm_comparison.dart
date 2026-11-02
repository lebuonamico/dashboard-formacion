import 'package:app_finnegans/features/courses/domain/course_category.dart';

/// Hours per category from each source for a group of employees. Moodle:
/// courses completed in the LMS at their workload (only Business and Soft
/// skills). CRM: declared hours in every category.
class MoodleCrmComparison {
  final Map<CourseCategory, double> moodle;
  final Map<CourseCategory, double> crm;

  /// Totals over the categories both sources have.
  final double moodleComparable;
  final double crmComparable;

  /// CRM hours over every category.
  final double crmTotal;

  /// Hours the CRM records above (or below, when negative) Moodle in the
  /// comparable categories.
  final double differenceComparable;

  /// The difference as a percentage of Moodle; `null` without Moodle hours.
  final double? percentageDifference;

  /// Less than 0.05 h apart counts as matching.
  final bool match;

  const MoodleCrmComparison({
    required this.moodle,
    required this.crm,
    required this.moodleComparable,
    required this.crmComparable,
    required this.crmTotal,
    required this.differenceComparable,
    required this.percentageDifference,
    required this.match,
  });
}
