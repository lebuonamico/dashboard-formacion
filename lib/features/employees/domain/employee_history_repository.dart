import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';

/// Lectura opcional de la infraestructura histórica existente en Supabase.
abstract class EmployeeHistoryRepository {
  Future<List<EmployeeHistoryEntry>> getEmployeeHistory();
}
