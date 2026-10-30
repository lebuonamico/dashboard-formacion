import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/cursada.dart';

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
