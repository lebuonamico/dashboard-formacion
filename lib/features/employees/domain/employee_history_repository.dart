import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';

/// Validity periods of each employee's seniority, area, team, manager and
/// status. They are written whenever the payroll changes, never by hand.
abstract interface class EmployeeHistoryRepository {
  Future<List<EmployeeHistoryEntry>> getEmployeeHistory();
}
