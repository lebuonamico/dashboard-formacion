import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:app_finnegans/features/teams/domain/teams_service.dart';
import 'package:flutter_test/flutter_test.dart';

EmployeeCompliance _member(
  String id,
  String team, {
  required double hours,
  double target = 8,
}) => const EmployeeComplianceService().summarize(
  employee: Employee(
    employeeId: id,
    firstName: 'Nombre $id',
    lastName: 'Apellido',
    seniority: Seniority.senior1,
    area: 'SERVICIOS',
    email: '$id@finnegans.com',
    team: team,
  ),
  creditedHours: {CourseCategory.businessSkills: hours},
  declaredHours: {CourseCategory.businessSkills: hours},
  requiredHours: {CourseCategory.businessSkills: target},
);

void main() {
  const service = TeamsService();

  group('Resumen del período', () {
    test('Calcula la cantidad de equipos, el desvío y el cumplimiento', () {
      final summary = service.buildPeriodSummary([
        _member('1', 'SOPORTE', hours: 8),
        _member('2', 'SOPORTE', hours: 8),
        _member('3', 'DESARROLLO', hours: 2),
      ]);

      expect(summary.teamCount, 2);
      expect(summary.employeeCount, 3);
      expect(summary.completedHours, 18);
      expect(summary.targetHours, 24);
      expect(summary.hoursDeviation, -6);
      expect(summary.overallCompletion, 75);
      expect(summary.businessHours, 18);
      expect((summary.onTarget, summary.atRisk, summary.critical), (1, 0, 1));
      expect(summary.teams.map((team) => team.name), ['DESARROLLO', 'SOPORTE']);
    });

    test('Sin horas requeridas el cumplimiento general es 0', () {
      final summary = service.buildPeriodSummary([
        _member('1', 'SOPORTE', hours: 5, target: 0),
      ]);

      expect(summary.targetHours, 0);
      expect(summary.hoursDeviation, 0);
      expect(summary.overallCompletion, 0);
      expect(summary.teams.single.status, TeamStatus.onTarget);
    });

    test('Usa la cantidad de colaboradores únicos si se la pasan', () {
      final summary = service.buildPeriodSummary([
        _member('1', 'SOPORTE', hours: 8),
        _member('1', 'DESARROLLO', hours: 8),
      ], uniqueEmployeeCount: 1);

      expect(summary.teamCount, 2);
      expect(summary.employeeCount, 1);
    });

    test('Sin datos todo queda en 0', () {
      const summary = TeamsPeriodSummary.noData();

      expect(summary.hasData, isFalse);
      expect(summary.teamCount, 0);
      expect(summary.hoursDeviation, 0);
      expect(summary.overallCompletion, 0);
    });
  });
}
