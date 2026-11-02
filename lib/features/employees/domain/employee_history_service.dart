import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';

class EmployeeHistoryService {
  const EmployeeHistoryService();

  /// The employee as they were during [entry].
  Employee rebuild(EmployeeHistoryEntry entry, Employee employee) =>
      employee.copyWith(
        seniority: entry.seniority,
        area: entry.area,
        team: entry.team,
        manager: entry.manager,
        isActive: entry.isActive,
      );

  /// The validity period in force on the day before [periodEnd]. Before the
  /// first recorded state it is that earliest state, not the current payroll.
  /// `null` when there is none or more than one.
  EmployeeHistoryEntry? effectiveAt(
    List<EmployeeHistoryEntry> history,
    DateTime periodEnd,
  ) {
    final effective = history.where((entry) {
      final until = entry.validTo;
      return entry.validFrom.isBefore(periodEnd) &&
          (until == null || !until.isBefore(periodEnd));
    }).toList();
    if (effective.isEmpty && history.isNotEmpty) {
      final earliest = history
          .map((entry) => entry.validFrom)
          .reduce((a, b) => b.isBefore(a) ? b : a);
      if (!earliest.isBefore(periodEnd)) {
        effective.addAll(
          history.where((entry) => entry.validFrom.isAtSameMomentAs(earliest)),
        );
      }
    }
    return effective.length == 1 ? effective.single : null;
  }
}
