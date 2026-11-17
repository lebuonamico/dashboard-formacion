import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_period_service.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/projection/domain/projection_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Junior 1: 4 h de Negocio y 4 de Blandas por mes con el plan por defecto.
Employee _employee(String id, DateTime hireDate) => Employee(
  employeeId: id,
  firstName: 'Nombre $id',
  lastName: 'Apellido',
  seniority: Seniority.junior1,
  area: 'Desarrollo',
  email: '$id@finnegans.com',
  team: 'Backend',
  hireDate: hireDate,
);

LmsCertification _completion(String employeeId, int month) => LmsCertification(
  employeeId: employeeId,
  courseName: 'Negociación',
  isCompleted: true,
  completedAt: DateTime(2026, month, 20),
);

void main() {
  const periods = CompliancePeriodService();
  const service = ProjectionService(periods: periods);
  final courses = [
    Course(
      id: 'N',
      name: 'Negociación',
      category: CourseCategory.businessSkills,
      courseArea: '',
      instructorEmployeeId: '',
      workloadHours: 4,
    ),
  ];

  // La empresa tiene datos de julio a septiembre; el nuevo ingresó en agosto.
  Map<int, List<EmployeeCompliance>> byMonth({int throughMonth = 9}) =>
      periods.calculateComplianceByMonth(
        employees: [
          _employee('1', DateTime(2025, 3, 1)),
          _employee('2', DateTime(2026, 8, 10)),
        ],
        courses: courses,
        timeEntries: const [],
        certifications: [
          for (final month in [7, 8, 9]) _completion('1', month),
          _completion('2', 8),
        ],
        year: 2026,
        throughMonth: throughMonth,
        complianceService: ComplianceService(),
      );

  List<String> idsIn(List<EmployeeCompliance> month) =>
      month.map((item) => item.employee.employeeId).toList();

  test('antes del ingreso el colaborador no figura en el mes', () {
    final months = byMonth();

    expect(months.keys, [7, 8, 9]);
    expect(idsIn(months[7]!), ['1']);
    expect(idsIn(months[8]!), ['1', '2']);
  });

  test('la proyección de cada uno cuenta sus meses desde el ingreso', () {
    final goals = {
      for (final projection in service.projectEmployees(
        byMonth: byMonth(),
        cutoffMonth: 9,
      ))
        projection.employeeId: projection.goal,
    };

    // Julio a septiembre más los 3 meses que faltan: 6 meses de 8 h.
    expect(goals['1'], 48);
    // Agosto y septiembre más los 3 que faltan: 5 meses de 8 h.
    expect(goals['2'], 40);
  });

  test('la proyección de la sección promedia esos objetivos', () {
    final projection = service.calculateForSection(
      byMonth: byMonth(),
      cutoffMonth: 9,
    )!;

    expect(projection.employeeCount, 2);
    expect(projection.goal, (48 + 40) / 2);
  });

  test('con el corte antes del ingreso no hay proyección del nuevo', () {
    final own = byMonth(throughMonth: 7).map(
      (month, items) => MapEntry(
        month,
        items.where((item) => item.employee.employeeId == '2').toList(),
      ),
    );

    expect(service.projectEmployee(own: own, cutoffMonth: 7), isNull);
  });
}
