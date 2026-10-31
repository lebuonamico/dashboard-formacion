import 'package:app_finnegans/features/employees/domain/employee.dart';

/// The payroll read from a file: one employee per ID, and how many rows it
/// had (a repeated row counts twice).
class PayrollImport {
  final List<Employee> employees;
  final int rowCount;

  const PayrollImport({required this.employees, required this.rowCount});
}
