import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

/// An employee's hours against their target, with the totals already
/// calculated by `EmployeeComplianceService.summarize`.
class EmployeeCompliance {
  final Employee employee;
  final Map<CourseCategory, double> creditedHours;
  final Map<CourseCategory, double> declaredHours;
  final Map<CourseCategory, double> requiredHours;

  /// Credited hours capped at each category's target. A category that is not
  /// required may have activity, but it adds nothing.
  final Map<CourseCategory, double> applicableHours;

  final double totalCreditedHours;
  final double totalDeclaredHours;
  final double totalRequiredHours;

  /// 0–100; 100 when nothing is required.
  final double totalPercentage;

  /// Every required category is met on its own: categories never compensate
  /// each other.
  final bool meetsTarget;

  const EmployeeCompliance({
    required this.employee,
    required this.creditedHours,
    required this.declaredHours,
    required this.requiredHours,
    required this.applicableHours,
    required this.totalCreditedHours,
    required this.totalDeclaredHours,
    required this.totalRequiredHours,
    required this.totalPercentage,
    required this.meetsTarget,
  });
}
