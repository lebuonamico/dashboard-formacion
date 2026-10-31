import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';

/// One validity period of an employee's payroll data.
class EmployeeHistoryEntry {
  final String employeeId;
  final Seniority seniority;
  final String area;
  final String team;
  final String manager;
  final bool isActive;
  final DateTime validFrom;
  final DateTime? validTo;

  const EmployeeHistoryEntry({
    required this.employeeId,
    required this.seniority,
    required this.area,
    required this.team,
    required this.manager,
    required this.isActive,
    required this.validFrom,
    this.validTo,
  });

  Employee rebuild(Employee employee) => employee.copyWith(
    seniority: seniority,
    area: area,
    team: team,
    manager: manager,
    active: isActive,
  );
}
