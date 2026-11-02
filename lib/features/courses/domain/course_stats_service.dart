import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/courses/domain/course_stats.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:collection/collection.dart';

class CourseStatsService {
  final CourseClassificationService classification;
  final EmployeeLookupService lookup;

  const CourseStatsService({
    required this.classification,
    this.lookup = const EmployeeLookupService(),
  });

  /// Every time entry counts, also teaching ones: in a teaching course the
  /// people who log hours are the ones who teach it.
  List<CourseStats> calculate({
    required List<Course> courses,
    required List<Employee> employees,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required bool Function(DateTime date) inPeriod,
  }) {
    final names = {
      for (final employee in employees)
        employee.employeeId: lookup.fullName(employee),
    };
    final entriesByCourse = groupBy(
      timeEntries.where((entry) => inPeriod(entry.date)),
      (CrmTimeEntry entry) => normalizeKey(entry.courseName),
    );
    final completionsByCourse = groupBy(
      certifications.where(
        (certification) =>
            certification.isCompleted &&
            certification.completedAt != null &&
            inPeriod(certification.completedAt!),
      ),
      (LmsCertification certification) =>
          normalizeKey(certification.courseName),
    );

    return courses.map((course) {
      final key = normalizeKey(course.name);
      final entries = entriesByCourse[key] ?? const <CrmTimeEntry>[];
      final completions =
          completionsByCourse[key] ?? const <LmsCertification>[];
      final people = entries.map((entry) => entry.employeeId).toSet().length;
      final hours = entries.fold(0.0, (total, entry) => total + entry.hours);
      return CourseStats(
        course: course,
        instructorName:
            names[course.instructorEmployeeId] ?? course.instructorEmployeeId,
        lmsCategory: classification.lmsCategory(course),
        people: people,
        crmHours: hours,
        averageHoursPerPerson: people == 0 ? null : hours / people,
        completed: completions.map((item) => item.employeeId).toSet().length,
      );
    }).toList();
  }
}
