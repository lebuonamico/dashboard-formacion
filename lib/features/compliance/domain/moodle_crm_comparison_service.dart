import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/moodle_crm_comparison.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

class MoodleCrmComparisonService {
  const MoodleCrmComparisonService();

  /// Categories present in both sources.
  static const comparables = [
    CourseCategory.businessSkills,
    CourseCategory.softSkills,
  ];

  MoodleCrmComparison compare(List<EmployeeCompliance> items) {
    double sum(
      Map<CourseCategory, double> Function(EmployeeCompliance) hours,
      CourseCategory category,
    ) => items.fold(0, (total, item) => total + (hours(item)[category] ?? 0));
    final moodle = {
      for (final category in comparables)
        category: sum((item) => item.creditedHours, category),
    };
    final crm = {
      for (final category in CourseCategory.values)
        category: sum((item) => item.declaredHours, category),
    };
    double total(Map<CourseCategory, double> hours, List<CourseCategory> of) =>
        of.fold(0, (total, category) => total + (hours[category] ?? 0));

    final moodleComparable = total(moodle, comparables);
    final crmComparable = total(crm, comparables);
    final difference = crmComparable - moodleComparable;
    return MoodleCrmComparison(
      moodle: moodle,
      crm: crm,
      moodleComparable: moodleComparable,
      crmComparable: crmComparable,
      crmTotal: total(crm, CourseCategory.values),
      differenceComparable: difference,
      percentageDifference: moodleComparable == 0
          ? null
          : difference / moodleComparable * 100,
      match: difference.abs() < 0.05,
    );
  }
}
