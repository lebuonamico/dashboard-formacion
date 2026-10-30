import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

/// Horas por categoría de cada fuente para un grupo de colaboradores.
/// Moodle: cursos finalizados en el LMS por su carga horaria (solo Negocio y
/// Blandas). CRM: horas declaradas en cada categoría.
class MoodleCrmComparison {
  final Map<CourseCategory, double> moodle;
  final Map<CourseCategory, double> crm;

  const MoodleCrmComparison({required this.moodle, required this.crm});

  /// Categorías que existen en las dos fuentes.
  static const comparables = [
    CourseCategory.businessSkills,
    CourseCategory.softSkills,
  ];

  factory MoodleCrmComparison.from(List<EmployeeCompliance> items) {
    double sum(
      Map<CourseCategory, double> Function(EmployeeCompliance) hours,
      CourseCategory type,
    ) => items.fold(0, (t, item) => t + (hours(item)[type] ?? 0));
    return MoodleCrmComparison(
      moodle: {
        for (final type in comparables)
          type: sum((item) => item.creditedHours, type),
      },
      crm: {
        for (final type in CourseCategory.values)
          type: sum((item) => item.declaredHours, type),
      },
    );
  }

  double totalMoodle(Iterable<CourseCategory> types) =>
      types.fold(0, (t, type) => t + (moodle[type] ?? 0));

  double totalCrm(Iterable<CourseCategory> types) =>
      types.fold(0, (t, type) => t + (crm[type] ?? 0));

  /// Horas que CRM registra de más (o de menos, si es negativa) que Moodle en
  /// las categorías comparables.
  double get differenceComparable =>
      totalCrm(comparables) - totalMoodle(comparables);

  /// La diferencia como porcentaje de lo registrado en Moodle; `null` si
  /// Moodle no tiene horas.
  double? get percentageDifference {
    final moodleComparable = totalMoodle(comparables);
    return moodleComparable == 0
        ? null
        : differenceComparable / moodleComparable * 100;
  }

  /// Menos de 0.05 h de diferencia se muestra como que coinciden.
  bool get match => differenceComparable.abs() < 0.05;
}
