import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/core/legacy/legacy_time_entry.dart';

abstract class TrainingRepository {
  Future<List<Employee>> getEmployees();
  Future<List<Course>> getCourses();
  Future<List<LegacyTimeEntry>> getLegacyTimeEntries();
  Future<void> replaceData({
    required List<Employee> employees,
    required List<Course> courses,
    required List<LegacyTimeEntry> timeEntries,
  });
  Future<void> resetToMock();
}
