import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';

/// Los colores de cada estado los resuelve la UI según el tema activo
/// (ver `widgets/shared/estado_colores.dart`).
enum ComplianceLevel {
  onTarget('En objetivo'),
  atRisk('En riesgo'),
  critical('Crítico');

  final String label;

  const ComplianceLevel(this.label);

  static ComplianceLevel fromPercentage(double percentage) {
    if (percentage >= 100.0) return ComplianceLevel.onTarget;
    if (percentage >= 70.0) return ComplianceLevel.atRisk;
    return ComplianceLevel.critical;
  }
}

class AreaComplianceViewModel {
  final String area;
  final int employeeCount;
  final double completedHours;
  final double requiredHours;
  final double compliancePercentage;
  final ComplianceLevel level;

  AreaComplianceViewModel({
    required this.area,
    required this.employeeCount,
    required this.completedHours,
    required this.requiredHours,
    required this.compliancePercentage,
    required this.level,
  });
}

final complianceByAreaProvider = FutureProvider<List<AreaComplianceViewModel>>((
  ref,
) async {
  final complianceList = await ref.watch(dashboardComplianceProvider.future);

  final groupedByArea = <String, List<EmployeeCompliance>>{};
  for (final item in complianceList) {
    groupedByArea.putIfAbsent(item.employee.area, () => []).add(item);
  }

  final result = <AreaComplianceViewModel>[];

  groupedByArea.forEach((area, items) {
    final completedHours = items.fold<double>(
      0.0,
      (acc, item) => acc + item.totalCreditedHours,
    );
    final requiredHours = items.fold<double>(
      0.0,
      (acc, item) => acc + item.totalRequiredHours,
    );

    final percentage = requiredHours == 0
        ? 100.0
        : (completedHours / requiredHours) * 100;

    result.add(
      AreaComplianceViewModel(
        area: area,
        // En el anual un legajo puede repetirse si cambió de equipo.
        employeeCount: items
            .map((item) => item.employee.employeeId)
            .toSet()
            .length,
        completedHours: completedHours,
        requiredHours: requiredHours,
        compliancePercentage: percentage,
        level: ComplianceLevel.fromPercentage(percentage),
      ),
    );
  });

  result.sort(
    (a, b) => b.compliancePercentage.compareTo(a.compliancePercentage),
  );
  return result;
});
