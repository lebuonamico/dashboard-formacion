import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_trend_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

Employee _employee(String employeeId) => Employee(
  hireDate: DateTime(2024, 1, 1),
  employeeId: employeeId,
  firstName: 'Persona',
  lastName: employeeId,
  seniority: Seniority.junior3,
  area: 'Desarrollo',
  email: '$employeeId@finnegans.com',
);

CrmTimeEntry _exploration(String employeeId, DateTime date) => CrmTimeEntry(
  id: '$employeeId-$date',
  courseName: 'Curso libre',
  employeeId: employeeId,
  date: date,
  hours: 1,
  kind: TimeEntryKind.taken,
  classification: 'Libres / exploración',
);

PeriodFilter _monthly(int month, [int year = 2026]) =>
    PeriodFilter(scope: PeriodScope.monthly, month: month, year: year);

PeriodFilter _annual(int year) =>
    PeriodFilter(scope: PeriodScope.annual, month: 1, year: year);

void main() {
  const service = DashboardTrendService();
  final july = _exploration('1', DateTime(2026, 7, 10));
  final september = _exploration('1', DateTime(2026, 9, 10));
  final lastYear = _exploration('1', DateTime(2025, 9, 10));
  final timeEntries = [july, september, lastYear];
  const noCertifications = <LmsCertification>[];

  test('Las horas del período se filtran por mes o por año', () {
    expect(service.timeEntriesInPeriod(timeEntries, _monthly(9)), [september]);
    expect(service.timeEntriesInPeriod(timeEntries, _annual(2026)), [
      july,
      september,
    ]);
  });

  test('Los meses evaluados son 1 en el mensual y los meses con datos en el '
      'anual, nunca 0', () {
    int months(PeriodFilter period) => service.evaluatedMonths(
      timeEntries: timeEntries,
      certifications: noCertifications,
      period: period,
    );

    expect(months(_monthly(8)), 1);
    expect(months(_annual(2026)), 2);
    expect(months(_annual(2024)), 1);
  });

  test('La serie termina en el mes elegido; en el anual, en el último mes '
      'con datos', () {
    DateTime end(PeriodFilter period) => service.evolutionEndMonth(
      timeEntries: timeEntries,
      certifications: [
        LmsCertification(
          employeeId: '1',
          courseName: 'Curso',
          isCompleted: true,
          completedAt: DateTime(2025, 11, 3),
        ),
      ],
      period: period,
    );

    expect(end(_monthly(5)), DateTime(2026, 5));
    expect(end(_annual(2026)), DateTime(2026, 9));
    expect(end(_annual(2025)), DateTime(2025, 11));
    expect(end(_annual(2024)), DateTime(2024, 12));
  });

  group('monthlyEvolution', () {
    // Junior 3 pide 8 h por defecto; desde septiembre, 6 h.
    final sixHours = TrainingPlan({
      for (final seniority in Seniority.values)
        seniority: seniority == Seniority.junior3
            ? {
                CourseCategory.businessSkills: 2,
                CourseCategory.softSkills: 3,
                CourseCategory.exploration: 1,
                CourseCategory.teaching: 0,
              }
            : TrainingPlanDefaults.hours[seniority]!,
    });
    final complianceService = ComplianceService(
      plans: TrainingPlanHistory([
        TrainingPlanVersion(validFrom: DateTime(2026, 9), plan: sixHours),
      ]),
    );

    List<({DateTime month, double hours, double target})> evolution({
      bool Function(Employee)? includeEmployee,
    }) => service
        .monthlyEvolution(
          employees: [_employee('1'), _employee('2')],
          courses: const [],
          timeEntries: timeEntries,
          certifications: noCertifications,
          period: _monthly(9),
          complianceService: complianceService,
          includeEmployee: includeEmployee,
        )
        .map(
          (point) =>
              (month: point.month, hours: point.hours, target: point.target),
        )
        .toList();

    test('Cuatro meses; los meses sin datos dan 0 h y 0 de meta', () {
      expect(evolution(), [
        (month: DateTime(2026, 6), hours: 0.0, target: 0.0),
        (month: DateTime(2026, 7), hours: 0.5, target: 8.0),
        (month: DateTime(2026, 8), hours: 0.0, target: 0.0),
        (month: DateTime(2026, 9), hours: 0.5, target: 6.0),
      ]);
    });

    test('La meta es el objetivo promedio del plan de cada mes, no 8 h', () {
      expect(evolution().last.target, 6);
    });

    test('Respeta el alcance del usuario', () {
      final onlyFirst = evolution(
        includeEmployee: (employee) => employee.employeeId == '1',
      );

      expect(onlyFirst.last.hours, 1);
      expect(onlyFirst.last.target, 6);
    });

    test('Un mes con datos pero sin elegibles da 0 h y 0 de meta', () {
      final none = evolution(includeEmployee: (_) => false);

      expect(none.last.hours, 0);
      expect(none.last.target, 0);
    });
  });
}
