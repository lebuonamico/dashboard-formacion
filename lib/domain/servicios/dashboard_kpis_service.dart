import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';

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
  const DashboardKpisService();

  DashboardAccumulatedCompliance accumulateCompliance(
    Iterable<TeamsPeriodSummary> months,
  ) {
    var creditedHours = 0.0;
    var targetHours = 0.0;
    for (final month in months) {
      if (!month.hasData || month.employeeCount == 0) continue;
      // Las horas de cada mes ya respetan elegibilidad, categorías y topes.
      creditedHours += month.completedHours;
      targetHours += month.targetHours;
    }
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
          .where((c) => !c.isTaught)
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
}
