import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class EmployeeCompliance {
  final Employee employee;
  final Map<CourseCategory, double> creditedHours;
  final Map<CourseCategory, double> declaredHours;
  final Map<CourseCategory, double> requiredHours;

  EmployeeCompliance({
    required this.employee,
    required this.creditedHours,
    required this.declaredHours,
    required this.requiredHours,
  });

  /// Horas que pueden aplicarse al objetivo de una categoría.
  /// Una categoría no requerida puede tener actividad, pero no suma cumplimiento.
  double applicableHours(CourseCategory type) {
    final required = requiredHours[type] ?? 0.0;
    if (required <= 0) return 0.0;

    return (creditedHours[type] ?? 0.0).clamp(0.0, required).toDouble();
  }

  double get totalCreditedHours => requiredHours.entries.fold(
    0.0,
    (total, requirement) => total + applicableHours(requirement.key),
  );

  double get totalDeclaredHours =>
      declaredHours.values.fold(0.0, (total, hours) => total + hours);

  double get totalRequiredHours =>
      requiredHours.values.fold(0.0, (acc, hours) => acc + hours);

  double get totalPercentage => totalRequiredHours == 0
      ? 100.0
      : (totalCreditedHours / totalRequiredHours * 100).clamp(0.0, 100.0);

  bool get meetsTarget => requiredHours.entries.every(
    (requirement) =>
        requirement.value == 0 ||
        (creditedHours[requirement.key] ?? 0) >= requirement.value,
  );
}
