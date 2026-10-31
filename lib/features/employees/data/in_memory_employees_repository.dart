import 'package:app_finnegans/features/employees/data/employees_seed.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_repository.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

/// Keeps the history the way the `empleado_historial` trigger does: each
/// employee starts with an open validity and every change to seniority,
/// area, team, manager or status closes it and opens a new one.
class InMemoryEmployeesRepository
    implements EmployeesRepository, EmployeeHistoryRepository {
  final DateTime Function() _now;
  final Map<String, Employee> _employees;
  final List<EmployeeHistoryEntry> _history;

  InMemoryEmployeesRepository({
    List<Employee>? employees,
    List<EmployeeHistoryEntry>? history,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _employees = {
         for (final employee in employees ?? employeesSeed)
           employee.employeeId: employee,
       },
       _history = [
         ...history ??
             (employees == null
                 ? employeeHistorySeed
                 : const <EmployeeHistoryEntry>[]),
       ] {
    final tracked = _history.map((entry) => entry.employeeId).toSet();
    _history.addAll(
      _employees.values
          .where((employee) => !tracked.contains(employee.employeeId))
          .map((employee) => _openEntry(employee, employee.hireDate ?? _now())),
    );
  }

  @override
  Future<List<Employee>> getEmployees() async => [..._employees.values];

  @override
  Future<List<EmployeeHistoryEntry>> getEmployeeHistory() async => [
    ..._history,
  ];

  @override
  Future<UpsertResult> upsert(List<Employee> employees) async {
    final unique = {
      for (final employee in employees) employee.employeeId: employee,
    };
    final insertedCount = unique.keys
        .where((id) => !_employees.containsKey(id))
        .length;
    final now = _now();
    for (final employee in unique.values) {
      final previous = _employees[employee.employeeId];
      if (previous == null || _tracked(previous) != _tracked(employee)) {
        _closeOpenEntry(employee.employeeId, now);
        _history.add(_openEntry(employee, now));
      }
      _employees[employee.employeeId] = employee;
    }
    return UpsertResult(
      processedRecords: employees.length,
      inserted: insertedCount,
      updated: unique.length - insertedCount,
    );
  }

  void _closeOpenEntry(String employeeId, DateTime now) {
    final index = _history.indexWhere(
      (entry) => entry.employeeId == employeeId && entry.validTo == null,
    );
    if (index == -1) return;
    final open = _history[index];
    _history[index] = EmployeeHistoryEntry(
      employeeId: open.employeeId,
      seniority: open.seniority,
      area: open.area,
      team: open.team,
      manager: open.manager,
      isActive: open.isActive,
      validFrom: open.validFrom,
      validTo: now,
    );
  }

  static EmployeeHistoryEntry _openEntry(Employee employee, DateTime from) =>
      EmployeeHistoryEntry(
        employeeId: employee.employeeId,
        seniority: employee.seniority,
        area: employee.area,
        team: employee.team,
        manager: employee.manager,
        isActive: employee.isActive,
        validFrom: from,
      );

  static Object _tracked(Employee employee) => (
    employee.seniority,
    employee.area,
    employee.team,
    employee.manager,
    employee.isActive,
  );
}
