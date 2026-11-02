import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_service.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:flutter_test/flutter_test.dart';

EmployeeHistoryEntry _entry(
  DateTime from, {
  DateTime? to,
  String team = 'QA',
  Seniority seniority = Seniority.junior1,
  bool active = true,
}) => EmployeeHistoryEntry(
  employeeId: '7',
  seniority: seniority,
  area: 'Core',
  team: team,
  manager: 'Rita',
  isActive: active,
  validFrom: from,
  validTo: to,
);

void main() {
  const service = EmployeeHistoryService();
  final august = _entry(DateTime(2026, 8), to: DateTime(2026, 9, 15));
  final september = _entry(
    DateTime(2026, 9, 15),
    team: 'Frontend',
    seniority: Seniority.junior2,
  );

  test('elige la vigencia al cierre del período', () {
    final history = [august, september];
    expect(service.effectiveAt(history, DateTime(2026, 9)), same(august));
    expect(service.effectiveAt(history, DateTime(2026, 10)), same(september));
  });

  test('antes del primer registro usa el primer estado conocido', () {
    expect(
      service.effectiveAt([august, september], DateTime(2026, 7)),
      same(august),
    );
  });

  test('sin historial o con dos vigencias superpuestas no hay una única', () {
    expect(service.effectiveAt([], DateTime(2026, 9)), isNull);
    final overlap = _entry(DateTime(2026, 8, 20), team: 'Backend');
    expect(service.effectiveAt([august, overlap], DateTime(2026, 9)), isNull);
  });

  test('rebuild aplica la vigencia sobre los datos personales', () {
    final employee = Employee(
      employeeId: '7',
      firstName: 'Ana',
      lastName: 'Ruiz',
      seniority: Seniority.senior3,
      area: 'Otra',
      email: 'ana@x.com',
      team: 'Otro',
      hireDate: DateTime(2024),
    );
    final rebuilt = service.rebuild(
      _entry(DateTime(2026), active: false),
      employee,
    );
    expect(rebuilt.seniority, Seniority.junior1);
    expect(rebuilt.area, 'Core');
    expect(rebuilt.team, 'QA');
    expect(rebuilt.manager, 'Rita');
    expect(rebuilt.isActive, isFalse);
    expect(rebuilt.email, 'ana@x.com');
    expect(rebuilt.hireDate, DateTime(2024));
    expect(const EmployeeLookupService().fullName(rebuilt), 'Ana Ruiz');
  });
}
