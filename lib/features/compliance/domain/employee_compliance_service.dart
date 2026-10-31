import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';

class EmployeeComplianceService {
  const EmployeeComplianceService();

  EmployeeCompliance summarize({
    required Employee employee,
    required Map<CourseCategory, double> creditedHours,
    required Map<CourseCategory, double> declaredHours,
    required Map<CourseCategory, double> requiredHours,
  }) {
    final applicable = {
      for (final category in CourseCategory.values)
        category: _applicable(
          creditedHours[category] ?? 0.0,
          requiredHours[category] ?? 0.0,
        ),
    };
    final totalCredited = requiredHours.keys.fold(
      0.0,
      (total, category) => total + applicable[category]!,
    );
    final totalRequired = requiredHours.values.fold(
      0.0,
      (total, hours) => total + hours,
    );
    return EmployeeCompliance(
      employee: employee,
      creditedHours: creditedHours,
      declaredHours: declaredHours,
      requiredHours: requiredHours,
      applicableHours: applicable,
      totalCreditedHours: totalCredited,
      totalDeclaredHours: declaredHours.values.fold(
        0.0,
        (total, hours) => total + hours,
      ),
      totalRequiredHours: totalRequired,
      totalPercentage: totalRequired == 0
          ? 100.0
          : (totalCredited / totalRequired * 100).clamp(0.0, 100.0),
      meetsTarget: requiredHours.entries.every(
        (requirement) =>
            requirement.value == 0 ||
            (creditedHours[requirement.key] ?? 0) >= requirement.value,
      ),
    );
  }

  static double _applicable(double credited, double required) =>
      required <= 0 ? 0.0 : credited.clamp(0.0, required).toDouble();
}
