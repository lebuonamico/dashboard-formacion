import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

abstract interface class EmployeesRepository {
  Future<List<Employee>> getEmployees();

  Future<UpsertResult> upsert(List<Employee> employees);
}
