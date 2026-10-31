import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_distribution.dart';

class DashboardAccumulatedCompliance {
  final double creditedHours;
  final double targetHours;
  final double compliance;

  const DashboardAccumulatedCompliance({
    required this.creditedHours,
    required this.targetHours,
    required this.compliance,
  });
}

class DashboardKpis {
  final int employees;
  final int training;
  final int evaluatedMonths;
  final double creditedHours;
  final double targetHours;
  final double declaredHours;
  final double compliance;
  final double monthlyPace;
  final double annualProjection;

  /// Objetivo de un año por colaborador, al ritmo de objetivo del período.
  /// Sale del plan de cada seniority: no es un valor fijo.
  final double annualGoalPerPerson;
  const DashboardKpis({
    required this.employees,
    required this.training,
    required this.evaluatedMonths,
    required this.creditedHours,
    required this.targetHours,
    required this.declaredHours,
    required this.compliance,
    required this.monthlyPace,
    required this.annualProjection,
    required this.annualGoalPerPerson,
  });
}

/// Cálculo extraído sin cambios de DashboardKpiGrid, compartido con el asistente.
class DashboardKpisService {
  final CourseClassificationService classification;

  final ComplianceLevelService levels;

  DashboardKpisService({
    CourseClassificationService? classification,
    this.levels = const ComplianceLevelService(),
  }) : classification = classification ?? CourseClassificationService();

  DashboardAccumulatedCompliance accumulateCompliance(
    Iterable<TeamsPeriodSummary> months,
  ) {
    // Las horas de cada mes ya respetan elegibilidad, categorías y topes.
    final evaluated = months
        .where((month) => month.hasData && month.employeeCount > 0)
        .toList();
    final creditedHours = evaluated.fold(
      0.0,
      (total, month) => total + month.completedHours,
    );
    final targetHours = evaluated.fold(
      0.0,
      (total, month) => total + month.targetHours,
    );
    return DashboardAccumulatedCompliance(
      creditedHours: creditedHours,
      targetHours: targetHours,
      compliance: _compliance(creditedHours, targetHours),
    );
  }

  double _compliance(double creditedHours, double targetHours) =>
      targetHours == 0 ? 0 : creditedHours / targetHours * 100;

  DashboardKpis calculate({
    required List<EmployeeCompliance> complianceList,
    required List<CrmTimeEntry> timeEntries,
    required int evaluatedMonths,
  }) {
    final employeeIds = {
      for (final item in complianceList) item.employee.employeeId,
    };
    final totalEmployees = employeeIds.length;
    final completedHours = complianceList.fold<double>(
      0,
      (t, i) => t + i.totalCreditedHours,
    );
    final targetHours = complianceList.fold<double>(
      0,
      (t, i) => t + i.totalRequiredHours,
    );
    final months = evaluatedMonths < 1 ? 1 : evaluatedMonths;
    final pace = totalEmployees == 0
        ? 0.0
        : completedHours / totalEmployees / months;
    // Mismo denominador que el ritmo, así la proyección y su meta comparan.
    final monthlyTarget = totalEmployees == 0
        ? 0.0
        : targetHours / totalEmployees / months;
    final payrollTimeEntries = timeEntries
        .where((c) => employeeIds.contains(c.employeeId))
        .toList();
    return DashboardKpis(
      employees: totalEmployees,
      training: payrollTimeEntries
          .where((c) => !classification.isTaught(c))
          .map((c) => c.employeeId)
          .toSet()
          .length,
      evaluatedMonths: months,
      creditedHours: completedHours,
      targetHours: targetHours,
      declaredHours: payrollTimeEntries.fold<double>(0, (t, c) => t + c.hours),
      compliance: _compliance(completedHours, targetHours),
      monthlyPace: pace,
      annualProjection: pace * 12,
      annualGoalPerPerson: monthlyTarget * 12,
    );
  }

  ComplianceDistribution complianceDistribution(
    List<EmployeeCompliance> complianceList,
  ) {
    final counts = complianceList
        .map((item) => levels.fromPercentage(item.totalPercentage))
        .fold(<ComplianceLevel, int>{}, (counts, level) {
          counts[level] = (counts[level] ?? 0) + 1;
          return counts;
        });
    final total = complianceList.length;
    final onTarget = counts[ComplianceLevel.onTarget] ?? 0;
    return ComplianceDistribution(
      total: total,
      onTarget: onTarget,
      atRisk: counts[ComplianceLevel.atRisk] ?? 0,
      critical: counts[ComplianceLevel.critical] ?? 0,
      onTargetShare: total == 0 ? 0 : onTarget / total,
    );
  }

  /// Only the hours that count towards the target, so the total matches the
  /// credited hours.
  CategoryDistribution categoryDistribution(
    List<EmployeeCompliance> complianceList,
  ) {
    double sum(double Function(EmployeeCompliance item) hours) =>
        complianceList.fold(0.0, (total, item) => total + hours(item));
    final hours = {
      for (final category in CourseCategory.values)
        category: sum((item) => item.applicableHours[category]!),
    };
    final people = complianceList.length;
    final totalCredited = sum((item) => item.totalCreditedHours);
    final totalTarget = sum((item) => item.totalRequiredHours);
    return CategoryDistribution(
      hours: hours,
      totalHours: hours.values.fold(0.0, (total, value) => total + value),
      averageHours: people == 0 ? 0 : totalCredited / people,
      averageTarget: people == 0 ? 0 : totalTarget / people,
      totalTarget: totalTarget,
    );
  }
}
