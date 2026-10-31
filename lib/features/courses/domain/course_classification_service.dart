import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/domain/course_category_parser.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

/// Which source credits each category: the LMS validates Business and Soft
/// skills courses; Exploration and Teaching come only from the CRM.
class CourseClassificationService {
  final CourseCategoryParser parser;

  CourseClassificationService({CourseCategoryParser? parser})
    : parser = parser ?? CourseCategoryParser();

  /// The course category when the LMS validates it, otherwise `null`.
  CourseCategory? lmsCategory(Course course) => switch (course.category) {
    CourseCategory.businessSkills ||
    CourseCategory.softSkills => course.category,
    _ => null,
  };

  /// The category in the entry's CRM Clasificación column, if recognised.
  CourseCategory? entryCategory(CrmTimeEntry entry) =>
      parser.tryParse(entry.classification);

  bool isTaught(CrmTimeEntry entry) =>
      entry.kind == TimeEntryKind.taught ||
      entryCategory(entry) == CourseCategory.teaching;

  /// Exploration or Teaching when the CRM alone credits the entry.
  CourseCategory? crmOnlyCategory(CrmTimeEntry entry) {
    if (isTaught(entry)) return CourseCategory.teaching;
    return entryCategory(entry) == CourseCategory.exploration
        ? CourseCategory.exploration
        : null;
  }
}
