import 'dart:async';

import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_editor_provider.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 10, 15);

class _PlanFake implements TrainingPlanRepository {
  TrainingPlanHistory plans = const TrainingPlanHistory.empty();
  final saved = <TrainingPlanVersion>[];
  Object? error;
  Completer<void>? gate;

  @override
  Future<TrainingPlanHistory> getPlans() async => plans;

  @override
  Future<void> saveVersion(TrainingPlanVersion version) async {
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    saved.add(version);
    plans = const TrainingPlanService().withVersion(plans, version);
  }
}

Future<(ProviderContainer, _PlanFake)> _setUp() async {
  final repository = _PlanFake();
  final container = ProviderContainer(
    overrides: [
      trainingPlanRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(() => _today),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  container.listen(trainingPlanEditorProvider, (_, _) {});
  await container.read(trainingPlanEditorProvider.future);
  return (container, repository);
}

TrainingPlanDraft _draft(ProviderContainer container) =>
    container.read(trainingPlanEditorProvider).requireValue;

TrainingPlanEditorNotifier _editor(ProviderContainer container) =>
    container.read(trainingPlanEditorProvider.notifier);

void main() {
  test('Arranca en el mes del reloj con el plan por defecto', () async {
    final (container, _) = await _setUp();
    final draft = _draft(container);

    expect(draft.validFrom, DateTime(2026, 10));
    expect(draft.base, TrainingPlanDefaults.plan);
    expect(
      draft.texts[(Seniority.junior1, CourseCategory.businessSkills)],
      '4',
    );
    expect(draft.hasChanges, isFalse);
    expect(draft.isPastMonth, isFalse);
    expect(draft.currentVersion, isNull);
  });

  test('Un valor inválido deja el plan editado en null', () async {
    final (container, _) = await _setUp();

    _editor(
      container,
    ).setHours(Seniority.manager, CourseCategory.exploration, '-2');

    expect(_draft(container).editedPlan, isNull);
    expect(_draft(container).hasChanges, isTrue);
  });

  test('Guardar escribe la versión del mes y la toma como base', () async {
    final (container, repository) = await _setUp();

    _editor(
      container,
    ).setHours(Seniority.junior1, CourseCategory.businessSkills, '5,5');
    await _editor(container).save();
    await container.read(trainingPlanEditorProvider.future);

    final saved = repository.saved.single;
    expect(saved.validFrom, DateTime(2026, 10));
    expect(
      saved.plan.hours[Seniority.junior1]![CourseCategory.businessSkills],
      5.5,
    );
    final draft = _draft(container);
    expect(draft.base, saved.plan);
    expect(draft.hasChanges, isFalse);
    expect(draft.isSaving, isFalse);
    expect(draft.currentVersion?.validFrom, DateTime(2026, 10));
  });

  test('Un error se relanza y deja el borrador como estaba', () async {
    final (container, repository) = await _setUp();
    repository.error = const FormatException('Sin permiso.');
    _editor(
      container,
    ).setHours(Seniority.trainee, CourseCategory.softSkills, '5');

    await expectLater(
      _editor(container).save(),
      throwsA(isA<FormatException>()),
    );

    final draft = _draft(container);
    expect(draft.isSaving, isFalse);
    expect(draft.hasChanges, isTrue);
    expect(draft.texts[(Seniority.trainee, CourseCategory.softSkills)], '5');
  });

  test('Mientras guarda queda en curso y no acepta cambios', () async {
    final (container, repository) = await _setUp();
    final gate = repository.gate = Completer<void>();
    _editor(
      container,
    ).setHours(Seniority.trainee, CourseCategory.softSkills, '5');

    final saving = _editor(container).save();
    expect(_draft(container).isSaving, isTrue);

    _editor(container).restoreDefaults();
    expect(
      _draft(container).texts[(Seniority.trainee, CourseCategory.softSkills)],
      '5',
    );

    gate.complete();
    await saving;
    await container.read(trainingPlanEditorProvider.future);
    expect(_draft(container).isSaving, isFalse);
    expect(repository.saved, hasLength(1));
  });

  test('Restaurar y descartar no guardan nada', () async {
    final (container, repository) = await _setUp();
    _editor(
      container,
    ).setHours(Seniority.junior1, CourseCategory.businessSkills, '6');

    _editor(container).discard();
    expect(_draft(container).hasChanges, isFalse);

    _editor(
      container,
    ).setHours(Seniority.junior1, CourseCategory.businessSkills, '6');
    _editor(container).restoreDefaults();
    expect(_draft(container).hasChanges, isFalse);
    expect(repository.saved, isEmpty);
  });

  test('Un mes anterior al del reloj es un mes pasado', () async {
    final (container, _) = await _setUp();

    container.read(trainingPlanEditorMonthProvider.notifier).select(2026, 9);
    await container.read(trainingPlanEditorProvider.future);

    expect(_draft(container).validFrom, DateTime(2026, 9));
    expect(_draft(container).isPastMonth, isTrue);
  });
}
