import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:flutter_test/flutter_test.dart';

Employee _employee({
  String id = '10',
  String team = 'Plataforma',
  DateTime? hireDate,
}) => Employee(
  employeeId: id,
  firstName: 'Ana',
  lastName: 'Pérez',
  seniority: Seniority.junior1,
  area: 'Producto',
  email: 'ana@finnegans.com',
  team: team,
  hireDate: hireDate ?? DateTime(2024, 3),
);

void main() {
  final importedAt = DateTime(2026, 10, 15);

  InMemoryEmployeesRepository repository(List<Employee> employees) =>
      InMemoryEmployeesRepository(employees: employees, now: () => importedAt);

  test(
    'cada empleado arranca con una vigencia abierta desde su ingreso',
    () async {
      final history = await repository([_employee()]).getEmployeeHistory();

      final entry = history.single;
      expect(entry.employeeId, '10');
      expect(entry.team, 'Plataforma');
      expect(entry.isActive, isTrue);
      expect(entry.validFrom, DateTime(2024, 3));
      expect(entry.validTo, isNull);
    },
  );

  test('un cambio de equipo cierra la vigencia y abre otra', () async {
    final repo = repository([_employee()]);

    await repo.upsert([_employee(team: 'Backend')]);

    final history = await repo.getEmployeeHistory();
    expect(
      history.map((entry) => (entry.team, entry.validFrom, entry.validTo)),
      [
        ('Plataforma', DateTime(2024, 3), importedAt),
        ('Backend', importedAt, null),
      ],
    );
  });

  test('un upsert sin cambios no agrega vigencias', () async {
    final repo = repository([_employee()]);

    final result = await repo.upsert([_employee()]);

    expect(await repo.getEmployeeHistory(), hasLength(1));
    expect((result.inserted, result.updated), (0, 1));
  });

  test('un alta abre su vigencia desde el momento de la importación', () async {
    final repo = repository([]);

    final result = await repo.upsert([_employee()]);

    final history = await repo.getEmployeeHistory();
    expect(history.single.validFrom, importedAt);
    expect((result.inserted, result.updated), (1, 0));
  });

  test('respeta el historial que recibe y completa el de los demás', () async {
    final repo = InMemoryEmployeesRepository(
      employees: [
        _employee(),
        _employee(id: '20'),
      ],
      history: [
        EmployeeHistoryEntry(
          employeeId: '10',
          seniority: Seniority.junior1,
          area: 'Producto',
          team: 'Plataforma',
          manager: '',
          isActive: false,
          validFrom: DateTime(2025),
        ),
      ],
    );

    final history = await repo.getEmployeeHistory();
    expect(
      history.map((entry) => (entry.employeeId, entry.validFrom)),
      unorderedEquals([('10', DateTime(2025)), ('20', DateTime(2024, 3))]),
    );
  });
}
