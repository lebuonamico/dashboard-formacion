import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_period_service.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:flutter_test/flutter_test.dart';

Employee _employee(String id, {bool isActive = true}) => Employee(
  employeeId: id,
  firstName: 'Nombre $id',
  lastName: 'Apellido',
  seniority: Seniority.junior1,
  area: 'Desarrollo',
  email: '$id@finnegans.com',
  team: 'Backend',
  hireDate: DateTime(2025, 1, 1),
  isActive: isActive,
);

Course _course(String name, CourseCategory category) => Course(
  id: name,
  name: name,
  category: category,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 4,
);

CrmTimeEntry _entry(String employeeId, String course, int month) =>
    CrmTimeEntry(
      id: '$employeeId-$course-$month',
      courseName: course,
      employeeId: employeeId,
      date: DateTime(2026, month, 10),
      hours: 3,
      kind: TimeEntryKind.taken,
    );

LmsCertification _completion(
  String employeeId,
  String course,
  int month, {
  bool isCompleted = true,
}) => LmsCertification(
  employeeId: employeeId,
  courseName: course,
  isCompleted: isCompleted,
  completedAt: DateTime(2026, month, 20),
);

PeriodFilter _monthly(int month) =>
    PeriodFilter(scope: PeriodScope.monthly, month: month, year: 2026);

const _annual = PeriodFilter(scope: PeriodScope.annual, month: 7, year: 2026);

List<(String, double, double)> _totals(List<EmployeeCompliance> items) => [
  for (final item in items)
    (
      item.employee.employeeId,
      item.totalCreditedHours,
      item.totalRequiredHours,
    ),
];

void main() {
  const service = CompliancePeriodService();
  final complianceService = ComplianceService();
  final courses = [
    _course('Negociación', CourseCategory.businessSkills),
    _course('Comunicación', CourseCategory.softSkills),
  ];
  final employees = [
    _employee('1'),
    _employee('2'),
    _employee('3', isActive: false),
  ];
  final timeEntries = [
    _entry('1', 'Negociación', 7),
    _entry('1', 'Comunicación', 8),
    _entry('2', 'Negociación', 7),
  ];
  final certifications = [
    _completion('1', 'Negociación', 7),
    _completion('1', 'Comunicación', 8),
    _completion('2', 'Negociación', 7),
    _completion('2', 'Comunicación', 8, isCompleted: false),
  ];

  group('calculateForPeriod', () {
    test('en el mensual es el cálculo del mes', () {
      final result = service.calculateForPeriod(
        employees: employees,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        period: _monthly(7),
        complianceService: complianceService,
      );

      expect(
        _totals(result),
        _totals(
          service.calculateMonthlyCompliance(
            employees: employees,
            courses: courses,
            timeEntries: timeEntries,
            certifications: certifications,
            year: 2026,
            month: 7,
            complianceService: complianceService,
          ),
        ),
      );
      expect(_totals(result), [('1', 4, 8), ('2', 4, 8)]);
    });

    test('en el anual suma los meses con datos', () {
      final result = service.calculateForPeriod(
        employees: employees,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        period: _annual,
        complianceService: complianceService,
      );

      expect(
        _totals(result),
        _totals(
          service.calculateAnnualCompliance(
            employees: employees,
            courses: courses,
            timeEntries: timeEntries,
            certifications: certifications,
            year: 2026,
            complianceService: complianceService,
          ),
        ),
      );
    });

    test('respeta el filtro de alcance', () {
      final result = service.calculateForPeriod(
        employees: employees,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        period: _monthly(7),
        complianceService: complianceService,
        includeEmployee: (employee) => employee.employeeId == '2',
      );

      expect(_totals(result), [('2', 4, 8)]);
    });
  });

  group('employeeCompliance', () {
    EmployeeCompliance profile(String id, PeriodFilter period) =>
        service.employeeCompliance(
          employee: employees.firstWhere((e) => e.employeeId == id),
          courses: courses,
          timeEntries: timeEntries,
          certifications: certifications,
          period: period,
          complianceService: complianceService,
        );

    test('en el mensual usa solo sus registros del mes', () {
      final july = profile('1', _monthly(7));

      expect(july.creditedHours[CourseCategory.businessSkills], 4);
      expect(july.creditedHours[CourseCategory.softSkills], 0);
      expect(july.declaredHours[CourseCategory.businessSkills], 3);
      expect(july.totalRequiredHours, 8);
    });

    test('una finalización pendiente no acredita', () {
      expect(profile('2', _monthly(8)).totalCreditedHours, 0);
    });

    test('en el anual el objetivo suma los 12 meses', () {
      final year = profile('1', _annual);

      expect(year.creditedHours[CourseCategory.businessSkills], 4);
      expect(year.creditedHours[CourseCategory.softSkills], 4);
      expect(year.totalRequiredHours, 96);
    });

    test('no exige elegibilidad: una baja tiene perfil', () {
      expect(profile('3', _monthly(7)).totalRequiredHours, 8);
    });
  });
}
