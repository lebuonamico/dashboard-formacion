import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

/// Activity of a catalog course in a period.
class CourseStats {
  final Course course;
  final String instructorName;

  /// The course category when the LMS validates it.
  final CourseCategory? lmsCategory;

  /// Distinct people who logged CRM hours for the course (in a teaching
  /// course, the people who taught it).
  final int people;

  /// CRM hours logged for the course.
  final double crmHours;

  /// `null` when nobody logged hours.
  final double? averageHoursPerPerson;

  /// Distinct people with an LMS completion of the course.
  final int completed;

  const CourseStats({
    required this.course,
    required this.instructorName,
    required this.lmsCategory,
    required this.people,
    required this.crmHours,
    required this.averageHoursPerPerson,
    required this.completed,
  });
}
