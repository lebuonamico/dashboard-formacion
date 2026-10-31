import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

/// Monthly hours required per category for each seniority.
class TrainingPlan {
  final Map<Seniority, Map<CourseCategory, double>> hours;

  const TrainingPlan(this.hours);

  TrainingPlan copyWith({Map<Seniority, Map<CourseCategory, double>>? hours}) =>
      TrainingPlan(hours ?? this.hours);

  Map<String, dynamic> toJson() => {
    for (final MapEntry(key: seniority, value: byCategory) in hours.entries)
      seniority.name: {
        for (final MapEntry(key: category, value: value) in byCategory.entries)
          category.name: value,
      },
  };

  factory TrainingPlan.fromJson(Map<String, dynamic> json) => TrainingPlan({
    for (final seniority in Seniority.values)
      if (json[seniority.name] case final Map<String, dynamic> byCategory)
        seniority: {
          for (final category in CourseCategory.values)
            if (byCategory[category.name] case final num value)
              category: value.toDouble(),
        },
  });

  @override
  bool operator ==(Object other) =>
      other is TrainingPlan &&
      Seniority.values.every(
        (seniority) => CourseCategory.values.every(
          (category) =>
              hours[seniority]?[category] == other.hours[seniority]?[category],
        ),
      );

  @override
  int get hashCode => Object.hashAll([
    for (final seniority in Seniority.values)
      for (final category in CourseCategory.values) hours[seniority]?[category],
  ]);
}

/// A plan and the month it rules from.
class TrainingPlanVersion {
  final DateTime validFrom;
  final TrainingPlan plan;

  const TrainingPlanVersion({required this.validFrom, required this.plan});

  TrainingPlanVersion copyWith({DateTime? validFrom, TrainingPlan? plan}) =>
      TrainingPlanVersion(
        validFrom: validFrom ?? this.validFrom,
        plan: plan ?? this.plan,
      );

  Map<String, dynamic> toJson() => {
    'validFrom': validFrom.toIso8601String(),
    'plan': plan.toJson(),
  };

  factory TrainingPlanVersion.fromJson(Map<String, dynamic> json) =>
      TrainingPlanVersion(
        validFrom: DateTime.parse(json['validFrom'].toString()),
        plan: TrainingPlan.fromJson(json['plan'] as Map<String, dynamic>),
      );
}

/// The plan versions, oldest first.
class TrainingPlanHistory {
  final List<TrainingPlanVersion> versions;

  const TrainingPlanHistory(this.versions);

  const TrainingPlanHistory.empty() : versions = const [];
}
