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

  EmployeeHistoryEntry copyWith({DateTime? validTo}) => EmployeeHistoryEntry(
    employeeId: employeeId,
    seniority: seniority,
    area: area,
    team: team,
    manager: manager,
    isActive: isActive,
    validFrom: validFrom,
    validTo: validTo ?? this.validTo,
  );
}
