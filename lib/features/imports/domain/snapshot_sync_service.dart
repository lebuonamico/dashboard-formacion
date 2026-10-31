import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';

/// The payroll and the course catalog are imported as the complete current
/// snapshot: whoever is missing is deactivated, never deleted, and whoever
/// comes back is reactivated.
class SnapshotSyncService {
  const SnapshotSyncService();

  Future<UpsertResult> syncPayroll(
    EmployeesRepository repository,
    List<Employee> employees,
  ) async {
    _requireKeys(employees.map((employee) => employee.employeeId), 'Nómina');
    final changes = _changes(
      previous: await repository.getEmployees(),
      incoming: employees,
      keyOf: (employee) => employee.employeeId,
      isActive: (employee) => employee.isActive,
      withActive: (employee, active) => employee.copyWith(active: active),
    );
    return _result(employees.length, await repository.upsert(changes));
  }

  /// A course that already exists with the same name keeps its current ID:
  /// the name is unique and hours and completions point to that ID.
  Future<UpsertResult> syncCourseCatalog(
    CoursesRepository repository,
    List<Course> courses,
  ) async {
    _requireKeys(courses.map((course) => course.id), 'Cursos');
    final previous = await repository.getCourses();
    final idByName = {
      for (final course in previous) normalizeLoose(course.name): course.id,
    };
    final changes = _changes(
      previous: previous,
      incoming: courses
          .map(
            (course) =>
                course.copyWith(id: idByName[normalizeLoose(course.name)]),
          )
          .toList(),
      keyOf: (course) => course.id,
      isActive: (course) => course.isActive,
      withActive: (course, active) => course.copyWith(active: active),
    );
    return _result(courses.length, await repository.upsert(changes));
  }

  static void _requireKeys(Iterable<String> keys, String snapshot) {
    if (keys.isEmpty || keys.any((key) => key.trim().isEmpty)) {
      throw FormatException(
        'La foto de $snapshot está vacía o tiene claves inválidas.',
      );
    }
  }

  static List<T> _changes<T>({
    required List<T> previous,
    required List<T> incoming,
    required String Function(T) keyOf,
    required bool Function(T) isActive,
    required T Function(T item, bool active) withActive,
  }) {
    final present = incoming.map(keyOf).toSet();
    return [
      ...incoming.map((item) => withActive(item, true)),
      ...previous
          .where((item) => isActive(item) && !present.contains(keyOf(item)))
          .map((item) => withActive(item, false)),
    ];
  }

  static UpsertResult _result(int processedRecords, UpsertResult written) =>
      UpsertResult(
        processedRecords: processedRecords,
        inserted: written.inserted,
        updated: written.updated,
      );
}
