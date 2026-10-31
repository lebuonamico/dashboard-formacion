import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';

/// Horas mensuales requeridas por categoría para cada seniority. Siempre
/// está completo y es válido: el constructor rechaza lo que no lo es.
class TrainingPlan {
  /// Tope por categoría y mes: un error de tipeo (80 en lugar de 8) no pasa
  /// como un objetivo válido.
  static const maxHoursPerCategory = 160.0;

  final Map<Seniority, Map<CourseCategory, double>> _hours;

  TrainingPlan(Map<Seniority, Map<CourseCategory, double>> hours)
    : _hours = Map.unmodifiable({
        for (final seniority in Seniority.values)
          seniority: Map<CourseCategory, double>.unmodifiable({
            for (final type in CourseCategory.values)
              type: _validate(seniority, type, hours[seniority]?[type]),
          }),
      });

  /// El plan que regía cuando estaba fijo en el código (los valores del enum
  /// [Seniority]). Es el de cualquier mes anterior a la primera versión.
  factory TrainingPlan.byDefault() => _byDefault;

  static final _byDefault = TrainingPlan({
    for (final seniority in Seniority.values)
      seniority: TrainingPlanDefaults.hours[seniority]!,
  });

  factory TrainingPlan.fromJson(Map<String, dynamic> json) => TrainingPlan({
    for (final seniority in Seniority.values)
      if (json[seniority.name] case final Map<String, dynamic> byType)
        seniority: {
          for (final type in CourseCategory.values)
            if (byType[type.name] case final num hours) type: hours.toDouble(),
        },
  });

  /// Mensaje de error para un valor de horas, o `null` si es válido. La misma
  /// regla que aplica el constructor, para validar campo por campo en la UI.
  static String? hoursError(double? hours) {
    if (hours == null || !hours.isFinite) return 'Ingresá un número';
    if (hours < 0) return 'No puede ser negativo';
    if (hours > maxHoursPerCategory) {
      return 'Máximo ${maxHoursPerCategory.toStringAsFixed(0)} h';
    }
    return null;
  }

  static double _validate(
    Seniority seniority,
    CourseCategory type,
    double? hours,
  ) {
    if (hours == null) {
      throw FormatException(
        'Al plan le falta ${type.label} para ${seniority.label}.',
      );
    }
    final error = hoursError(hours);
    if (error != null) {
      throw FormatException(
        '${seniority.label}, ${type.label}: $error ($hours).',
      );
    }
    return hours;
  }

  Map<CourseCategory, double> requiredHours(Seniority seniority) =>
      _hours[seniority]!;

  double total(Seniority seniority) =>
      _hours[seniority]!.values.fold(0.0, (total, hours) => total + hours);

  Map<String, dynamic> toJson() => {
    for (final MapEntry(key: seniority, value: byType) in _hours.entries)
      seniority.name: {
        for (final MapEntry(key: type, value: hours) in byType.entries)
          type.name: hours,
      },
  };

  @override
  bool operator ==(Object other) =>
      other is TrainingPlan &&
      Seniority.values.every(
        (seniority) => CourseCategory.values.every(
          (type) => _hours[seniority]![type] == other._hours[seniority]![type],
        ),
      );

  @override
  int get hashCode => Object.hashAll([
    for (final seniority in Seniority.values)
      for (final type in CourseCategory.values) _hours[seniority]![type],
  ]);
}

/// Un plan y el mes desde el que rige.
class TrainingPlanVersion {
  /// Primer día del mes.
  final DateTime validFrom;
  final TrainingPlan plan;

  TrainingPlanVersion({required DateTime validFrom, required this.plan})
    : validFrom = DateTime(validFrom.year, validFrom.month);

  factory TrainingPlanVersion.fromJson(Map<String, dynamic> json) =>
      TrainingPlanVersion(
        validFrom: DateTime.parse(json['vigenteDesde'].toString()),
        plan: TrainingPlan.fromJson(json['plan'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
    'vigenteDesde': dateIso(validFrom),
    'plan': plan.toJson(),
  };

  /// `yyyy-mm-dd`, el formato de una columna `date`.
  static String dateIso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Las versiones del plan, una por mes como máximo. Cada mes se evalúa con
/// la versión vigente en ese mes, así cambiar el plan no reescribe los meses
/// ya evaluados (el mismo criterio que el historial de la nómina).
class TrainingPlanHistory {
  /// De la más vieja a la más nueva.
  final List<TrainingPlanVersion> versions;

  const TrainingPlanHistory.empty() : versions = const [];

  TrainingPlanHistory(Iterable<TrainingPlanVersion> versions)
    : versions = List.unmodifiable(_sorted(versions));

  static List<TrainingPlanVersion> _sorted(
    Iterable<TrainingPlanVersion> versions,
  ) {
    final items = versions.toList()
      ..sort((a, b) => a.validFrom.compareTo(b.validFrom));
    for (var i = 1; i < items.length; i++) {
      if (items[i].validFrom == items[i - 1].validFrom) {
        throw FormatException(
          'Hay dos planes de formación que rigen desde '
          '${TrainingPlanVersion.dateIso(items[i].validFrom)}.',
        );
      }
    }
    return items;
  }

  /// La versión que rige en ese mes, o `null` si es anterior a la primera
  /// (entonces rige el plan por defecto).
  TrainingPlanVersion? currentVersionIn(int year, int month) {
    final start = DateTime(year, month);
    for (final version in versions.reversed) {
      if (!version.validFrom.isAfter(start)) return version;
    }
    return null;
  }

  TrainingPlan currentIn(int year, int month) =>
      currentVersionIn(year, month)?.plan ?? TrainingPlan.byDefault();

  TrainingPlan get current {
    final today = DateTime.now();
    return currentIn(today.year, today.month);
  }

  /// Suma de los 12 objetivos mensuales del año, cada uno con su versión.
  Map<CourseCategory, double> requiredForYear(Seniority seniority, int year) {
    final total = {for (final type in CourseCategory.values) type: 0.0};
    for (var month = 1; month <= 12; month++) {
      final plan = currentIn(year, month).requiredHours(seniority);
      for (final type in CourseCategory.values) {
        total[type] = total[type]! + plan[type]!;
      }
    }
    return total;
  }

  /// Agrega la versión, o reemplaza la que rige desde ese mismo mes.
  TrainingPlanHistory withVersion(TrainingPlanVersion version) =>
      TrainingPlanHistory([
        for (final current in versions)
          if (current.validFrom != version.validFrom) current,
        version,
      ]);
}
