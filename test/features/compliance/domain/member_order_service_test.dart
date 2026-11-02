import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/compliance/domain/member_order.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:flutter_test/flutter_test.dart';

EmployeeCompliance _member(
  String employeeId,
  String lastName, {
  double hours = 0,
  String team = 'Core',
  Seniority seniority = Seniority.junior1,
}) => const EmployeeComplianceService().summarize(
  employee: Employee(
    employeeId: employeeId,
    firstName: 'Persona',
    lastName: lastName,
    seniority: seniority,
    area: 'Desarrollo',
    email: 'persona$employeeId@finnegans.com',
    team: team,
    isActive: true,
  ),
  creditedHours: {CourseCategory.softSkills: hours},
  declaredHours: {CourseCategory.softSkills: hours},
  requiredHours: {CourseCategory.softSkills: 10},
);

List<String> _lastNames(List<EmployeeCompliance> members) =>
    members.map((member) => member.employee.lastName).toList();

void main() {
  const service = MemberOrderService();

  test('Sin columna conserva el orden recibido', () {
    final members = [_member('2', 'B'), _member('1', 'A')];

    expect(service.sort(members, const MemberOrder()), same(members));
  });

  test('Los legajos numéricos se ordenan por valor', () {
    final members = [_member('10', 'Diez'), _member('9', 'Nueve')];

    expect(
      _lastNames(
        service.sort(members, const MemberOrder(column: MemberSort.employeeId)),
      ),
      ['Nueve', 'Diez'],
    );
  });

  test('Ordena por nombre, equipo, seniority, horas y cumplimiento', () {
    final members = [
      _member('1', 'Carla', hours: 2, team: 'b', seniority: Seniority.senior1),
      _member('2', 'Ana', hours: 8, team: 'C', seniority: Seniority.trainee),
      _member('3', 'Beto', hours: 5, team: 'a', seniority: Seniority.junior2),
    ];
    List<String> by(MemberSort column) =>
        _lastNames(service.sort(members, MemberOrder(column: column)));

    expect(by(MemberSort.employee), ['Ana', 'Beto', 'Carla']);
    expect(by(MemberSort.team), ['Beto', 'Carla', 'Ana']);
    expect(by(MemberSort.seniority), ['Ana', 'Beto', 'Carla']);
    expect(by(MemberSort.hours), ['Carla', 'Beto', 'Ana']);
    expect(by(MemberSort.compliance), ['Carla', 'Beto', 'Ana']);
  });

  test('Descendente invierte el orden y el desempate por nombre', () {
    final members = [
      _member('1', 'Ana', hours: 5),
      _member('2', 'Beto', hours: 5),
      _member('3', 'Carla', hours: 1),
    ];

    expect(
      _lastNames(
        service.sort(members, const MemberOrder(column: MemberSort.hours)),
      ),
      ['Carla', 'Ana', 'Beto'],
    );
    expect(
      _lastNames(
        service.sort(
          members,
          const MemberOrder(column: MemberSort.hours, ascending: false),
        ),
      ),
      ['Beto', 'Ana', 'Carla'],
    );
  });
}
