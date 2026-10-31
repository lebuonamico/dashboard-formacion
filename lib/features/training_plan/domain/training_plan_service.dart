import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';

enum HoursIssue { notANumber, negative, aboveMax }

/// A plan with a missing or invalid value. The message is generic: the
/// editor shows the detail of each field.
class InvalidTrainingPlanException extends FormatException {
  final Seniority seniority;
  final CourseCategory category;

  /// `null` when the value is missing.
  final HoursIssue? issue;

  const InvalidTrainingPlanException(this.seniority, this.category, this.issue)
    : super('El plan de formación está incompleto o tiene horas inválidas.');
}

/// Each month is evaluated with the version ruling in that month, so changing
/// the plan never rewrites months already evaluated (the same criterion as the
/// payroll history).
class TrainingPlanService {
  /// A typo (80 instead of 8) does not pass as a valid target.
  static const maxHoursPerCategory = 160.0;

  final DateTime Function() now;

  const TrainingPlanService({this.now = DateTime.now});

  HoursIssue? hoursIssue(double? hours) {
    if (hours == null || !hours.isFinite) return HoursIssue.notANumber;
    if (hours < 0) return HoursIssue.negative;
    if (hours > maxHoursPerCategory) return HoursIssue.aboveMax;
    return null;
  }

  /// The plan with every seniority and category, in unmodifiable maps.
  TrainingPlan validate(TrainingPlan plan) => TrainingPlan(
    Map.unmodifiable({
      for (final seniority in Seniority.values)
        seniority: Map<CourseCategory, double>.unmodifiable({
          for (final category in CourseCategory.values)
            category: _validHours(plan, seniority, category),
        }),
    }),
  );

  double _validHours(
    TrainingPlan plan,
    Seniority seniority,
    CourseCategory category,
  ) {
    final hours = plan.hours[seniority]?[category];
    if (hours == null) {
      throw InvalidTrainingPlanException(seniority, category, null);
    }
    final issue = hoursIssue(hours);
    if (issue != null) {
      throw InvalidTrainingPlanException(seniority, category, issue);
    }
    return hours;
  }

  double total(TrainingPlan plan, Seniority seniority) =>
      plan.hours[seniority]!.values.fold(0.0, (total, hours) => total + hours);

  /// The version on the first day of its month.
  TrainingPlanVersion version({
    required DateTime validFrom,
    required TrainingPlan plan,
  }) => TrainingPlanVersion(validFrom: _monthStart(validFrom), plan: plan);

  /// Sorted versions; two versions for the same month are an error.
  TrainingPlanHistory history(Iterable<TrainingPlanVersion> versions) {
    final sorted =
        versions
            .map((v) => version(validFrom: v.validFrom, plan: v.plan))
            .toList()
          ..sort((a, b) => a.validFrom.compareTo(b.validFrom));
    final repeated = [
      for (var i = 1; i < sorted.length; i++)
        if (sorted[i].validFrom == sorted[i - 1].validFrom) sorted[i],
    ].firstOrNull;
    if (repeated != null) {
      throw FormatException(
        'Hay dos planes de formación que rigen desde '
        '${dateIso(repeated.validFrom)}.',
      );
    }
    return TrainingPlanHistory(List.unmodifiable(sorted));
  }

  /// Adds the version, or replaces the one ruling from that same month.
  TrainingPlanHistory withVersion(
    TrainingPlanHistory history,
    TrainingPlanVersion added,
  ) {
    final start = _monthStart(added.validFrom);
    return this.history([
      ...history.versions.where((current) => current.validFrom != start),
      added,
    ]);
  }

  /// The version ruling in that month, or `null` before the first one (then
  /// the default plan rules).
  TrainingPlanVersion? currentVersionIn(
    TrainingPlanHistory history,
    int year,
    int month,
  ) {
    final start = DateTime(year, month);
    return history.versions.reversed
        .where((version) => !version.validFrom.isAfter(start))
        .firstOrNull;
  }

  TrainingPlan currentIn(TrainingPlanHistory history, int year, int month) =>
      currentVersionIn(history, year, month)?.plan ?? TrainingPlanDefaults.plan;

  TrainingPlan current(TrainingPlanHistory history) {
    final today = now();
    return currentIn(history, today.year, today.month);
  }

  /// The 12 monthly targets of the year, each with its own version.
  Map<CourseCategory, double> requiredForYear(
    TrainingPlanHistory history,
    Seniority seniority,
    int year,
  ) => {
    for (final category in CourseCategory.values)
      category: List.generate(12, (index) => index + 1).fold(
        0.0,
        (total, month) =>
            total +
            currentIn(history, year, month).hours[seniority]![category]!,
      ),
  };

  /// `yyyy-mm-dd`, the format of a `date` column.
  String dateIso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);
}
