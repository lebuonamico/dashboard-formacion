import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_kpis_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';

EmployeeCompliance _compliance(
  String employeeId, {
  required double required,
  double valid = 0,
}) => const EmployeeComplianceService().summarize(
  employee: Employee(
    employeeId: employeeId,
    firstName: 'Nombre $employeeId',
    lastName: '',
    seniority: Seniority.junior1,
    area: 'Área',
    email: '$employeeId@finnegans.com',
  ),
  creditedHours: {CourseCategory.businessSkills: valid},
  declaredHours: const {},
  requiredHours: {CourseCategory.businessSkills: required},
);

void main() {
  final service = DashboardKpisService();

  test('La meta anual sale del objetivo del plan, no de 96 h fijas', () {
    // Un plan de 8 h y otro de 10 h: 9 h por persona y mes.
    final kpis = service.calculate(
      complianceList: [
        _compliance('1', required: 8, valid: 8),
        _compliance('2', required: 10, valid: 4),
      ],
      timeEntries: const [],
      evaluatedMonths: 1,
    );

    expect(kpis.annualGoalPerPerson, 9 * 12);
    expect(kpis.annualProjection, 6 * 12);
  });

  test('En el anual divide por los meses evaluados, igual que el ritmo', () {
    // Tres meses de 8 h acumulados en el objetivo de cada persona.
    final kpis = service.calculate(
      complianceList: [
        _compliance('1', required: 24, valid: 12),
        _compliance('2', required: 24, valid: 6),
      ],
      timeEntries: const [],
      evaluatedMonths: 3,
    );

    expect(kpis.annualGoalPerPerson, 96);
    expect(kpis.monthlyPace, 3);
  });

  test('Sin colaboradores la meta es 0', () {
    final kpis = service.calculate(
      complianceList: const [],
      timeEntries: const [],
      evaluatedMonths: 1,
    );

    expect(kpis.annualGoalPerPerson, 0);
  });
}
