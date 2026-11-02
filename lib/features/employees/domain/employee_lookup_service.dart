import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';

class EmployeeLookupService {
  const EmployeeLookupService();

  String fullName(Employee employee) =>
      '${employee.firstName} ${employee.lastName}';

  /// The payroll row with that email, compared without spaces or case. With
  /// two rows, the active one wins.
  Employee? findByEmail(Iterable<Employee> employees, String? email) {
    final searched = normalizeLoose(email ?? '');
    if (searched.isEmpty) return null;
    final matches = employees.where(
      (employee) => normalizeLoose(employee.email) == searched,
    );
    return matches.where((employee) => employee.isActive).firstOrNull ??
        matches.firstOrNull;
  }
}
