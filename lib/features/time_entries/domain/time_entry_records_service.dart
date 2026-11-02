import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry_record.dart';

class TimeEntryRecordsService {
  final CourseClassificationService classification;

  const TimeEntryRecordsService({required this.classification});

  CrmTimeEntryRecord record(
    CrmTimeEntry timeEntry, {
    required Employee? employee,
    required Course? course,
  }) => CrmTimeEntryRecord(
    timeEntry: timeEntry,
    employee: employee,
    course: course,
    isTaught: classification.isTaught(timeEntry),
  );

  /// The entries inside the period, joined with the payroll by employee id
  /// and with the catalog by trimmed lowercase name, most recent first.
  List<CrmTimeEntryRecord> join({
    required List<CrmTimeEntry> timeEntries,
    required List<Employee> employees,
    required List<Course> courses,
    required bool Function(DateTime date) inPeriod,
  }) {
    final employeesById = {
      for (final employee in employees) employee.employeeId: employee,
    };
    final coursesByName = {
      for (final course in courses) normalizeLoose(course.name): course,
    };
    return timeEntries
        .where((timeEntry) => inPeriod(timeEntry.date))
        .map(
          (timeEntry) => record(
            timeEntry,
            employee: employeesById[timeEntry.employeeId],
            course: coursesByName[normalizeLoose(timeEntry.courseName)],
          ),
        )
        .toList()
      ..sort((a, b) => b.timeEntry.date.compareTo(a.timeEntry.date));
  }
}
