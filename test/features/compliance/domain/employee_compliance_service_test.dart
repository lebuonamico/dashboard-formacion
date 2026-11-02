import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:flutter_test/flutter_test.dart';

Map<CourseCategory, double> _hours({
  double business = 0,
  double soft = 0,
  double exploration = 0,
  double teaching = 0,
}) => {
  CourseCategory.businessSkills: business,
  CourseCategory.softSkills: soft,
  CourseCategory.exploration: exploration,
  CourseCategory.teaching: teaching,
};

void main() {
  const service = EmployeeComplianceService();
  final employee = Employee(
    employeeId: '1',
    firstName: 'Ana',
    lastName: 'Ruiz',
    seniority: Seniority.manager,
    area: 'Core',
    email: 'ana@x.com',
  );

  test('topea cada categoría y descarta las no requeridas', () {
    final compliance = service.summarize(
      employee: employee,
      creditedHours: _hours(soft: 5, exploration: 10),
      declaredHours: _hours(soft: 5, exploration: 12),
      requiredHours: _hours(exploration: 8),
    );

    expect(compliance.applicableHours[CourseCategory.softSkills], 0);
    expect(compliance.applicableHours[CourseCategory.exploration], 8);
    expect(compliance.totalCreditedHours, 8);
    expect(compliance.totalDeclaredHours, 17);
    expect(compliance.totalRequiredHours, 8);
    expect(compliance.totalPercentage, 100);
    expect(compliance.meetsTarget, isTrue);
  });

  test('una categoría no compensa a otra', () {
    final compliance = service.summarize(
      employee: employee,
      creditedHours: _hours(soft: 8),
      declaredHours: _hours(soft: 8),
      requiredHours: _hours(business: 4, soft: 4),
    );

    expect(compliance.totalCreditedHours, 4);
    expect(compliance.totalPercentage, 50);
    expect(compliance.meetsTarget, isFalse);
  });

  test('sin requisito cuenta como 100 %', () {
    final compliance = service.summarize(
      employee: employee,
      creditedHours: _hours(),
      declaredHours: _hours(),
      requiredHours: _hours(),
    );

    expect(compliance.totalPercentage, 100);
    expect(compliance.meetsTarget, isTrue);
  });

  test('los cortes del semáforo son 100 y 70', () {
    const levels = ComplianceLevelService();
    expect(levels.fromPercentage(100), ComplianceLevel.onTarget);
    expect(levels.fromPercentage(99.9), ComplianceLevel.atRisk);
    expect(levels.fromPercentage(70), ComplianceLevel.atRisk);
    expect(levels.fromPercentage(69.9), ComplianceLevel.critical);
  });
}
