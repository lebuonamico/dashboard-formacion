import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

/// Si, con la tendencia de cada colaborador, se llega a la meta de fin de año.
enum ProjectionStatus {
  onTrack('En camino'),
  reachable('Alcanzable'),
  atRisk('En riesgo');

  final String label;
  const ProjectionStatus(this.label);

  /// [percentage] es la parte de la meta que se proyecta cubrir.
  static ProjectionStatus fromPercentage(double percentage) {
    if (percentage >= 100) return ProjectionStatus.onTrack;
    if (percentage >= 85) return ProjectionStatus.reachable;
    return ProjectionStatus.atRisk;
  }
}

/// Proyección de una categoría para un colaborador, en horas.
class CategoryProjection {
  final CourseCategory type;

  /// Horas sin tope de los meses con datos hasta el corte.
  final double accumulated;

  /// Objetivo de los meses con datos hasta el corte más los que faltan.
  final double goal;

  /// Acumulado más lo que estima la tendencia para los meses que faltan.
  final double projected;

  const CategoryProjection({
    required this.type,
    required this.accumulated,
    required this.goal,
    required this.projected,
  });

  bool get arrives => projected >= goal;

  /// Horas que le faltan a fin de año con su tendencia.
  double get missing => arrives ? 0 : goal - projected;
}

/// Proyección a fin de año de un colaborador, solo con las categorías que
/// pide su seniority.
class EmployeeProjection {
  final String employeeId;
  final int cutoffMonth;
  final List<CategoryProjection> categories;

  /// [percentage] de su proyección cortada en el mes con datos anterior;
  /// `null` si no hay un mes anterior en el que haya estado.
  final double? previousPercentage;

  const EmployeeProjection({
    required this.employeeId,
    required this.cutoffMonth,
    required this.categories,
    this.previousPercentage,
  });

  /// Puntos de la meta que mejoró (o empeoró) contra el mes anterior.
  double? get variation =>
      previousPercentage == null ? null : percentage - previousPercentage!;

  int get remainingMonths => 12 - cutoffMonth;

  /// Cumple todas sus categorías.
  bool get arrives => categories.every((c) => c.arrives);

  /// Horas proyectadas, cada categoría topeada en su meta.
  double get projection => categories.fold(
    0,
    (t, c) => t + (c.projected < c.goal ? c.projected : c.goal),
  );

  double get goal => categories.fold(0, (t, c) => t + c.goal);

  double get percentage => goal == 0 ? 100 : projection / goal * 100;

  ProjectionStatus get status => ProjectionStatus.fromPercentage(percentage);

  /// Categorías que no llegan, la que más falta primero.
  List<CategoryProjection> get missing =>
      categories.where((c) => !c.arrives).toList()
        ..sort((a, b) => b.missing.compareTo(a.missing));
}

/// Proyección a fin de año de una sección, cortada en [cutoffMonth]. Se calcula
/// por colaborador y categoría y después se agrupa: las horas de una persona
/// nunca cubren lo que le falta a otra, ni las de una categoría a otra.
/// Los valores en horas son promedios por persona.
class AnnualProjection {
  final int cutoffMonth;
  final int employeeCount;

  /// Colaboradores que, con su tendencia, cumplen todas sus categorías.
  final int arrive;

  /// Horas proyectadas a diciembre, cada una topeada en la meta de su
  /// categoría.
  final double projection;

  /// Objetivo de los meses con datos hasta el corte más los que faltan.
  final double goal;

  /// Horas acumuladas hasta el corte, topeadas en la meta de su categoría.
  final double accumulated;

  /// Horas que les faltan, con su tendencia, a quienes no llegan.
  final double missing;

  final ProjectionStatus status;

  /// Cumplimiento del mes de corte, con el tope mensual, en porcentaje.
  final double monthCompliance;

  /// Horas del mes de corte con el tope mensual.
  final double recentPace;

  /// Horas del mes anterior al corte con el tope mensual; `null` si ese mes no
  /// tiene datos.
  final double? previousMonthPace;

  /// [percentage] de la proyección cortada en el mes con datos anterior;
  /// `null` si no hay un mes anterior con datos.
  final double? previousPercentage;

  const AnnualProjection({
    required this.cutoffMonth,
    required this.employeeCount,
    required this.arrive,
    required this.projection,
    required this.goal,
    required this.accumulated,
    required this.missing,
    required this.status,
    required this.monthCompliance,
    required this.recentPace,
    required this.previousMonthPace,
    this.previousPercentage,
  });

  int get remainingMonths => 12 - cutoffMonth;

  double get percentage => goal == 0 ? 100 : projection / goal * 100;

  /// Puntos de la meta que mejoró (o empeoró) la proyección contra la del
  /// mes anterior.
  double? get projectionVariation =>
      previousPercentage == null ? null : percentage - previousPercentage!;

  /// Horas por persona y por mes que hay que sumar a la tendencia para
  /// llegar; 0 si ya no quedan meses.
  double get adjustment => remainingMonths == 0 ? 0 : missing / remainingMonths;

  /// Diferencia de horas por persona contra el mes anterior.
  double? get variation =>
      previousMonthPace == null ? null : recentPace - previousMonthPace!;
}

class ProjectionService {
  const ProjectionService();

  /// [byMonth] tiene el cumplimiento mensual de los meses con datos hasta el
  /// corte; un mes sin datos de nadie no está y no cuenta. Se proyecta a los
  /// colaboradores del mes de corte, con todo su historial del año. Devuelve
  /// `null` si el mes de corte no tiene colaboradores.
  AnnualProjection? calculate({
    required Map<int, List<EmployeeCompliance>> byMonth,
    required int cutoffMonth,
  }) {
    final current = _calculate(byMonth: byMonth, cutoffMonth: cutoffMonth);
    if (current == null) return null;

    // La misma proyección, cortada en el mes con datos anterior.
    final previous =
        byMonth.entries
            .where((e) => e.key < cutoffMonth && e.value.isNotEmpty)
            .map((e) => e.key)
            .toList()
          ..sort();
    if (previous.isEmpty) return current;
    final preview = _calculate(byMonth: byMonth, cutoffMonth: previous.last);
    return AnnualProjection(
      cutoffMonth: current.cutoffMonth,
      employeeCount: current.employeeCount,
      arrive: current.arrive,
      projection: current.projection,
      goal: current.goal,
      accumulated: current.accumulated,
      missing: current.missing,
      status: current.status,
      monthCompliance: current.monthCompliance,
      recentPace: current.recentPace,
      previousMonthPace: current.previousMonthPace,
      previousPercentage: preview?.percentage,
    );
  }

  AnnualProjection? _calculate({
    required Map<int, List<EmployeeCompliance>> byMonth,
    required int cutoffMonth,
  }) {
    final atCutoff = byMonth[cutoffMonth] ?? const [];
    if (atCutoff.isEmpty) return null;

    final employees = projectEmployees(
      byMonth: byMonth,
      cutoffMonth: cutoffMonth,
    );
    var projection = 0.0;
    var goal = 0.0;
    var accumulated = 0.0;
    var missing = 0.0;
    for (final employee in employees) {
      projection += employee.projection;
      goal += employee.goal;
      for (final category in employee.categories) {
        accumulated += category.accumulated < category.goal
            ? category.accumulated
            : category.goal;
        missing += category.missing;
      }
    }
    final arrive = employees.where((e) => e.arrives).length;

    final n = employees.length;
    double withCap(List<EmployeeCompliance> items) =>
        items.fold<double>(0, (t, c) => t + c.totalCreditedHours);
    final cutoffHours = withCap(atCutoff);
    final cutoffTarget = atCutoff.fold<double>(
      0,
      (t, c) => t + c.totalRequiredHours,
    );
    final previous = byMonth[cutoffMonth - 1] ?? const [];

    return AnnualProjection(
      cutoffMonth: cutoffMonth,
      employeeCount: n,
      arrive: arrive,
      projection: projection / n,
      goal: goal / n,
      accumulated: accumulated / n,
      missing: missing / n,
      status: ProjectionStatus.fromPercentage(
        goal == 0 ? 100 : projection / goal * 100,
      ),
      monthCompliance: cutoffTarget == 0
          ? 100
          : cutoffHours / cutoffTarget * 100,
      recentPace: cutoffHours / n,
      previousMonthPace: previous.isEmpty
          ? null
          : withCap(previous) / previous.length,
    );
  }

  /// Proyección de cada colaborador del mes de corte, por categoría, con todo
  /// su historial del año en [byMonth]. Solo incluye las categorías con meta.
  List<EmployeeProjection> projectEmployees({
    required Map<int, List<EmployeeCompliance>> byMonth,
    required int cutoffMonth,
  }) {
    // Historial de cada colaborador por legajo: mes -> cumplimiento.
    final history = <String, Map<int, EmployeeCompliance>>{};
    for (final entry in byMonth.entries) {
      if (entry.key > cutoffMonth) continue;
      for (final item in entry.value) {
        (history[item.employee.employeeId] ??= {})[entry.key] = item;
      }
    }

    final remaining = 12 - cutoffMonth;
    final employeeIds = {
      for (final item in byMonth[cutoffMonth] ?? const <EmployeeCompliance>[])
        item.employee.employeeId,
    };

    return [
      for (final employeeId in employeeIds)
        () {
          final months = history[employeeId]!;
          final cutoff = months[cutoffMonth]!;
          final categories = <CategoryProjection>[];

          for (final type in CourseCategory.values) {
            final points = <({int month, double hours})>[];
            var goal = 0.0;
            for (final MapEntry(key: month, value: item) in months.entries) {
              final required = item.requiredHours[type] ?? 0;
              goal += required;
              // Sin tope mensual; solo cuentan los meses en que era requerida.
              points.add((
                month: month,
                hours: required > 0 ? item.creditedHours[type] ?? 0 : 0,
              ));
            }
            goal += (cutoff.requiredHours[type] ?? 0) * remaining;
            if (goal <= 0) continue;

            final accumulated = points.fold<double>(0, (t, p) => t + p.hours);
            final trend = _regression(points);
            var future = 0.0;
            for (var month = cutoffMonth + 1; month <= 12; month++) {
              final estimated = trend(month);
              if (estimated > 0) future += estimated;
            }
            categories.add(
              CategoryProjection(
                type: type,
                accumulated: accumulated,
                goal: goal,
                projected: accumulated + future,
              ),
            );
          }
          return EmployeeProjection(
            employeeId: employeeId,
            cutoffMonth: cutoffMonth,
            categories: categories,
          );
        }(),
    ];
  }

  /// Regresión lineal simple de las horas sobre el mes. Con un solo mes, la
  /// tendencia es plana.
  double Function(int month) _regression(
    List<({int month, double hours})> points,
  ) {
    final n = points.length;
    final meanX = points.fold<double>(0, (t, p) => t + p.month) / n;
    final meanY = points.fold<double>(0, (t, p) => t + p.hours) / n;
    var covariance = 0.0;
    var variance = 0.0;
    for (final p in points) {
      covariance += (p.month - meanX) * (p.hours - meanY);
      variance += (p.month - meanX) * (p.month - meanX);
    }
    final pending = variance == 0 ? 0.0 : covariance / variance;
    final sorted = meanY - pending * meanX;
    return (month) => sorted + pending * month;
  }
}
