import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';

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
        level: const ComplianceLevelService().fromPercentage(percentage),
      ),
    );
  });

  result.sort(
    (a, b) => b.compliancePercentage.compareTo(a.compliancePercentage),
  );
  return result;
});
