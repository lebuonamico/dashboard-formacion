import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_editor_provider.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/training_plan/presentation/training_plan_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';

class _PlanFake implements TrainingPlanRepository {
  TrainingPlanHistory plans;
  final saved = <TrainingPlanVersion>[];

  _PlanFake([this.plans = const TrainingPlanHistory.empty()]);

  @override
  Future<TrainingPlanHistory> getPlans() async => plans;

  @override
  Future<void> saveVersion(TrainingPlanVersion version) async {
    saved.add(version);
    plans = const TrainingPlanService().withVersion(plans, version);
  }
}

Future<ProviderContainer> _showEditor(
  WidgetTester tester,
  _PlanFake repository, {
  DateTime? today,
}) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      trainingPlanRepositoryProvider.overrideWithValue(repository),
      if (today != null) clockProvider.overrideWithValue(() => today),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: TrainingPlanEditor()),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return container;
}

Finder _field(Seniority seniority, CourseCategory type) =>
    find.byKey(Key('plan_${seniority.name}_${type.name}'));

String _total(WidgetTester tester, Seniority seniority) =>
    tester.widget<Text>(find.byKey(Key('plan_total_${seniority.name}'))).data!;

Finder _dialogText(String text, {bool partial = false}) => find.descendant(
  of: find.byType(AlertDialog),
  matching: partial ? find.textContaining(text) : find.text(text),
);

bool _canSave(WidgetTester tester) =>
    tester
        .widget<ButtonStyleButton>(find.byKey(const Key('plan_guardar')))
        .onPressed !=
    null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pasa Junior 1 a 6 h de negocio y 2 de blandas y lo guarda', (
    tester,
  ) async {
    final repository = _PlanFake();
    final container = await _showEditor(tester, repository);

    expect(_total(tester, Seniority.junior1), '8 h');
    expect(_canSave(tester), isFalse);

    await tester.enterText(
      _field(Seniority.junior1, CourseCategory.businessSkills),
      '6',
    );
    await tester.enterText(
      _field(Seniority.junior1, CourseCategory.softSkills),
      '2',
    );
    await tester.pump();

    expect(_total(tester, Seniority.junior1), '8 h');
    expect(_canSave(tester), isTrue);

    await tester.tap(find.byKey(const Key('plan_guardar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan_confirmar')));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final saved = repository.saved.single;
    expect(saved.validFrom, DateTime(today.year, today.month));
    expect(saved.plan.hours[Seniority.junior1]!, {
      CourseCategory.businessSkills: 6,
      CourseCategory.softSkills: 2,
      CourseCategory.exploration: 0,
      CourseCategory.teaching: 0,
    });
    // El resto queda como estaba.
    expect(
      saved.plan.hours[Seniority.senior2]!,
      TrainingPlanDefaults.hours[Seniority.senior2]!,
    );
    expect(find.textContaining('Plan guardado: rige desde'), findsOneWidget);
    // El plan guardado es la nueva base: no quedan cambios pendientes.
    expect(_canSave(tester), isFalse);
    // Y el cálculo de cumplimiento ya lo usa.
    final service = await container.read(complianceServiceProvider.future);
    expect(
      const TrainingPlanService().currentIn(
        service.plans,
        today.year,
        today.month,
      ),
      saved.plan,
    );
  });

  testWidgets('Guardar pide confirmación y cancelar no guarda', (tester) async {
    final repository = _PlanFake();
    await _showEditor(tester, repository, today: DateTime(2026, 10, 15));

    await tester.enterText(
      _field(Seniority.junior1, CourseCategory.businessSkills),
      '6',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('plan_guardar')));
    await tester.pumpAndSettle();

    expect(_dialogText('Guardar plan'), findsOneWidget);
    expect(
      _dialogText('El plan rige desde Octubre 2026', partial: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.saved, isEmpty);
    expect(_canSave(tester), isTrue);
  });

  testWidgets('En un mes pasado la confirmación lo advierte', (tester) async {
    final repository = _PlanFake();
    final container = await _showEditor(
      tester,
      repository,
      today: DateTime(2026, 10, 15),
    );

    container.read(trainingPlanEditorMonthProvider.notifier).select(2026, 9);
    await tester.pumpAndSettle();
    expect(find.textContaining('Es un mes pasado'), findsOneWidget);

    await tester.enterText(
      _field(Seniority.trainee, CourseCategory.softSkills),
      '5',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('plan_guardar')));
    await tester.pumpAndSettle();

    expect(_dialogText('Guardar plan de un mes pasado'), findsOneWidget);
    expect(
      _dialogText('Septiembre 2026 ya fue evaluado', partial: true),
      findsOneWidget,
    );
    expect(find.text('Guardar igual'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan_confirmar')));
    await tester.pumpAndSettle();

    expect(repository.saved.single.validFrom, DateTime(2026, 9));
    expect(
      find.text('Plan guardado: rige desde Septiembre 2026.'),
      findsOneWidget,
    );
  });

  testWidgets('El total es libre y acepta coma decimal', (tester) async {
    await _showEditor(tester, _PlanFake());

    await tester.enterText(
      _field(Seniority.trainee, CourseCategory.businessSkills),
      '5,5',
    );
    await tester.pump();

    expect(_total(tester, Seniority.trainee), '9,5 h');
    expect(_canSave(tester), isTrue);
  });

  testWidgets('Un valor inválido marca el campo y no deja guardar', (
    tester,
  ) async {
    final repository = _PlanFake();
    await _showEditor(tester, repository);

    await tester.enterText(
      _field(Seniority.manager, CourseCategory.exploration),
      '-2',
    );
    await tester.pump();

    expect(find.text('No puede ser negativo'), findsOneWidget);
    expect(_total(tester, Seniority.manager), '—');
    expect(_canSave(tester), isFalse);

    await tester.enterText(
      _field(Seniority.manager, CourseCategory.exploration),
      'ocho',
    );
    await tester.pump();
    expect(find.text('Ingresá un número'), findsOneWidget);
    expect(_canSave(tester), isFalse);
    expect(repository.saved, isEmpty);
  });

  testWidgets('Restaurar trae los valores por defecto sin guardar', (
    tester,
  ) async {
    final today = DateTime.now();
    final changed = TrainingPlan({
      for (final seniority in Seniority.values)
        seniority: seniority == Seniority.junior1
            ? {
                CourseCategory.businessSkills: 6,
                CourseCategory.softSkills: 2,
                CourseCategory.exploration: 0,
                CourseCategory.teaching: 0,
              }
            : TrainingPlanDefaults.hours[seniority]!,
    });
    final repository = _PlanFake(
      TrainingPlanHistory([
        TrainingPlanVersion(
          validFrom: DateTime(today.year, today.month),
          plan: changed,
        ),
      ]),
    );
    await _showEditor(tester, repository);

    // Arranca con la versión guardada del mes actual.
    expect(
      tester
          .widget<TextField>(
            _field(Seniority.junior1, CourseCategory.businessSkills),
          )
          .controller!
          .text,
      '6',
    );
    expect(
      find.text('Estás editando la versión que rige desde ese mes.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('plan_restaurar')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            _field(Seniority.junior1, CourseCategory.businessSkills),
          )
          .controller!
          .text,
      '4',
    );
    expect(_canSave(tester), isTrue);
    expect(repository.saved, isEmpty);

    await tester.tap(find.byKey(const Key('plan_descartar')));
    await tester.pump();
    expect(_canSave(tester), isFalse);
  });
}
