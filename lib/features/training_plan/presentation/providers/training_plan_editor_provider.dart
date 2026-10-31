import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_providers.dart';
import 'package:app_finnegans/features/training_plan/presentation/training_plan_hours_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef PlanCell = (Seniority, CourseCategory);

/// The month the edited version rules from, on its first day.
final trainingPlanEditorMonthProvider =
    NotifierProvider.autoDispose<TrainingPlanEditorMonthNotifier, DateTime>(
      TrainingPlanEditorMonthNotifier.new,
    );

class TrainingPlanEditorMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final today = ref.watch(clockProvider)();
    return DateTime(today.year, today.month);
  }

  void select(int year, int month) => state = DateTime(year, month);
}

/// The form of the editor. [texts] keeps what was typed, so invalid values
/// can be shown; [editedPlan] is `null` while any of them is invalid.
class TrainingPlanDraft {
  final TrainingPlanHistory history;
  final DateTime validFrom;

  /// The plan ruling in [validFrom]: changes are marked against it.
  final TrainingPlan base;
  final Map<PlanCell, String> texts;
  final TrainingPlan? editedPlan;
  final bool hasChanges;
  final bool isPastMonth;
  final TrainingPlanVersion? currentVersion;
  final TrainingPlanVersion? nextVersion;
  final bool isSaving;

  const TrainingPlanDraft({
    required this.history,
    required this.validFrom,
    required this.base,
    required this.texts,
    required this.editedPlan,
    required this.hasChanges,
    required this.isPastMonth,
    required this.currentVersion,
    required this.nextVersion,
    this.isSaving = false,
  });

  TrainingPlanDraft copyWith({bool? isSaving}) => TrainingPlanDraft(
    history: history,
    validFrom: validFrom,
    base: base,
    texts: texts,
    editedPlan: editedPlan,
    hasChanges: hasChanges,
    isPastMonth: isPastMonth,
    currentVersion: currentVersion,
    nextVersion: nextVersion,
    isSaving: isSaving ?? this.isSaving,
  );
}

final trainingPlanEditorProvider =
    AsyncNotifierProvider.autoDispose<
      TrainingPlanEditorNotifier,
      TrainingPlanDraft
    >(TrainingPlanEditorNotifier.new);

/// Saving invalidates the history: compliance recalculates and the draft is
/// rebuilt with the saved plan as its base.
class TrainingPlanEditorNotifier extends AsyncNotifier<TrainingPlanDraft> {
  @override
  Future<TrainingPlanDraft> build() async {
    final service = ref.watch(trainingPlanServiceProvider);
    final today = ref.watch(clockProvider)();
    final validFrom = ref.watch(trainingPlanEditorMonthProvider);
    final history = await ref.watch(trainingPlanHistoryProvider.future);
    final base = service.currentIn(history, validFrom.year, validFrom.month);
    return _draft(service, today, history, validFrom, base, _textsOf(base));
  }

  void setHours(Seniority seniority, CourseCategory category, String text) =>
      _replaceTexts((texts) => {...texts, (seniority, category): text});

  void restoreDefaults() =>
      _replaceTexts((_) => _textsOf(TrainingPlanDefaults.plan));

  void discard() => _replaceTexts((_) => _textsOf(state.requireValue.base));

  Future<void> save() async {
    final current = state.value;
    final plan = current?.editedPlan;
    if (current == null ||
        plan == null ||
        !current.hasChanges ||
        current.isSaving) {
      return;
    }
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await ref
          .read(trainingPlanRepositoryProvider)
          .saveVersion(
            TrainingPlanVersion(validFrom: current.validFrom, plan: plan),
          );
      ref.invalidate(trainingPlanHistoryProvider);
      await ref.read(trainingPlanHistoryProvider.future);
    } finally {
      // After a successful save the draft is being rebuilt from the history.
      if (ref.mounted && !state.isLoading && state.value?.isSaving == true) {
        state = AsyncData(state.requireValue.copyWith(isSaving: false));
      }
    }
  }

  void _replaceTexts(
    Map<PlanCell, String> Function(Map<PlanCell, String> texts) change,
  ) {
    final current = state.value;
    if (current == null || current.isSaving) return;
    state = AsyncData(
      _draft(
        ref.read(trainingPlanServiceProvider),
        ref.read(clockProvider)(),
        current.history,
        current.validFrom,
        current.base,
        change(current.texts),
      ),
    );
  }

  static TrainingPlanDraft _draft(
    TrainingPlanService service,
    DateTime today,
    TrainingPlanHistory history,
    DateTime validFrom,
    TrainingPlan base,
    Map<PlanCell, String> texts,
  ) {
    final editedPlan = _plan(service, texts);
    return TrainingPlanDraft(
      history: history,
      validFrom: validFrom,
      base: base,
      texts: Map.unmodifiable(texts),
      editedPlan: editedPlan,
      hasChanges: editedPlan != base,
      isPastMonth: validFrom.isBefore(DateTime(today.year, today.month)),
      currentVersion: service.currentVersionIn(
        history,
        validFrom.year,
        validFrom.month,
      ),
      nextVersion: history.versions
          .where((version) => version.validFrom.isAfter(validFrom))
          .firstOrNull,
    );
  }

  static TrainingPlan? _plan(
    TrainingPlanService service,
    Map<PlanCell, String> texts,
  ) {
    final hours = {
      for (final seniority in Seniority.values)
        seniority: {
          for (final category in CourseCategory.values)
            category: parsePlanHours(texts[(seniority, category)] ?? ''),
        },
    };
    final valid = hours.values.every(
      (byCategory) =>
          byCategory.values.every((value) => service.hoursIssue(value) == null),
    );
    if (!valid) return null;
    return TrainingPlan({
      for (final MapEntry(key: seniority, value: byCategory) in hours.entries)
        seniority: byCategory.map(
          (category, value) => MapEntry(category, value!),
        ),
    });
  }

  static Map<PlanCell, String> _textsOf(TrainingPlan plan) => {
    for (final seniority in Seniority.values)
      for (final category in CourseCategory.values)
        (seniority, category): formatPlanHours(
          plan.hours[seniority]![category]!,
        ),
  };
}
