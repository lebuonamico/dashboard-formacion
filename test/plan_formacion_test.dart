import 'dart:convert';

import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/domain/modelos/plan_formacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El plan por defecto con Junior 1 en 6 h de negocio y 2 de blandas.
TrainingPlan _junior1SixTwo() => TrainingPlan({
  for (final seniority in Seniority.values)
    seniority: seniority == Seniority.junior1
        ? {
            CourseCategory.businessSkills: 6,
            CourseCategory.softSkills: 2,
            CourseCategory.exploration: 0,
            CourseCategory.teaching: 0,
          }
        : seniority.trainingPlan,
});

void main() {
  group('PlanFormacion', () {
    test('el plan por defecto es la tabla del enum Seniority', () {
      final plan = TrainingPlan.byDefault();

      for (final seniority in Seniority.values) {
        expect(plan.requiredHours(seniority), seniority.trainingPlan);
      }
      expect(plan.requiredHours(Seniority.semisenior3), {
        CourseCategory.businessSkills: 1,
        CourseCategory.softSkills: 4,
        CourseCategory.exploration: 1,
        CourseCategory.teaching: 2,
      });
      expect(plan.total(Seniority.manager), 8);
    });

    test('el total de cada seniority es libre', () {
      final plan = TrainingPlan({
        for (final seniority in Seniority.values)
          seniority: seniority == Seniority.trainee
              ? {
                  CourseCategory.businessSkills: 6,
                  CourseCategory.softSkills: 4,
                  CourseCategory.exploration: 0,
                  CourseCategory.teaching: 0,
                }
              : seniority.trainingPlan,
      });

      expect(plan.total(Seniority.trainee), 10);
      expect(plan.total(Seniority.junior1), 8);
    });

    test('rechaza un plan incompleto o con horas inválidas', () {
      Map<Seniority, Map<CourseCategory, double>> withJunior1(
        Map<CourseCategory, double> hours,
      ) => {
        for (final seniority in Seniority.values)
          seniority: seniority == Seniority.junior1
              ? hours
              : seniority.trainingPlan,
      };

      expect(
        () => TrainingPlan({Seniority.trainee: Seniority.trainee.trainingPlan}),
        throwsFormatException,
      );
      expect(
        () => TrainingPlan(
          withJunior1({
            CourseCategory.businessSkills: 4,
            CourseCategory.softSkills: 4,
            CourseCategory.exploration: 0,
          }),
        ),
        throwsFormatException,
      );
      for (final invalid in [-1.0, double.nan, double.infinity, 161.0]) {
        expect(
          () => TrainingPlan(
            withJunior1({
              CourseCategory.businessSkills: invalid,
              CourseCategory.softSkills: 4,
              CourseCategory.exploration: 0,
              CourseCategory.teaching: 0,
            }),
          ),
          throwsFormatException,
          reason: '$invalid',
        );
      }
    });

    test('errorHoras aplica la misma regla, campo por campo', () {
      expect(TrainingPlan.hoursError(null), isNotNull);
      expect(TrainingPlan.hoursError(-0.5), isNotNull);
      expect(TrainingPlan.hoursError(160.5), isNotNull);
      expect(TrainingPlan.hoursError(0), isNull);
      expect(TrainingPlan.hoursError(2.5), isNull);
      expect(TrainingPlan.hoursError(160), isNull);
    });

    test('se compara por valor y sobrevive al JSON', () {
      final plan = _junior1SixTwo();
      final copy = TrainingPlan.fromJson(
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>,
      );

      expect(copy, plan);
      expect(copy.hashCode, plan.hashCode);
      expect(copy, isNot(TrainingPlan.byDefault()));
    });
  });

  group('PlanesFormacion', () {
    final july = TrainingPlanVersion(
      validFrom: DateTime(2026, 7, 15),
      plan: _junior1SixTwo(),
    );

    test('la vigencia se normaliza al primer día del mes', () {
      expect(july.validFrom, DateTime(2026, 7));
    });

    test('antes de la primera versión rige el plan por defecto', () {
      final plans = TrainingPlanHistory([july]);

      expect(plans.currentIn(2026, 6), TrainingPlan.byDefault());
      expect(plans.currentVersionIn(2026, 6), isNull);
      expect(
        const TrainingPlanHistory.empty().currentIn(2026, 7),
        TrainingPlan.byDefault(),
      );
    });

    test('cada mes usa la última versión que ya empezó', () {
      final october = TrainingPlanVersion(
        validFrom: DateTime(2026, 10),
        plan: TrainingPlan.byDefault(),
      );
      // Desordenadas a propósito.
      final plans = TrainingPlanHistory([october, july]);

      expect(plans.versions.map((v) => v.validFrom), [
        DateTime(2026, 7),
        DateTime(2026, 10),
      ]);
      expect(plans.currentIn(2026, 7), july.plan);
      expect(plans.currentIn(2026, 9), july.plan);
      expect(plans.currentIn(2026, 10), TrainingPlan.byDefault());
      expect(plans.currentIn(2027, 3), TrainingPlan.byDefault());
    });

    test('dos versiones del mismo mes son un error', () {
      expect(() => TrainingPlanHistory([july, july]), throwsFormatException);
    });

    test('conVersion reemplaza la del mismo mes', () {
      final plans = TrainingPlanHistory([july]).withVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 7),
          plan: TrainingPlan.byDefault(),
        ),
      );

      expect(plans.versions, hasLength(1));
      expect(plans.currentIn(2026, 8), TrainingPlan.byDefault());
    });

    test('el objetivo anual suma los 12 meses con su versión', () {
      final plans = TrainingPlanHistory([july]);

      // Enero a junio 4/4 por defecto, julio a diciembre 6/2.
      expect(plans.requiredForYear(Seniority.junior1, 2026), {
        CourseCategory.businessSkills: 6 * 4.0 + 6 * 6.0,
        CourseCategory.softSkills: 6 * 4.0 + 6 * 2.0,
        CourseCategory.exploration: 0.0,
        CourseCategory.teaching: 0.0,
      });
      // Sin cambios es el plan mensual × 12.
      expect(
        plans.requiredForYear(Seniority.senior1, 2026),
        Seniority.senior1.trainingPlan.map((type, h) => MapEntry(type, h * 12)),
      );
    });
  });

  group('LocalPlanFormacionRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sin nada guardado no hay versiones', () async {
      final plans = await LocalTrainingPlanRepository().getPlans();

      expect(plans.versions, isEmpty);
    });

    test('guarda versiones y reemplaza la del mismo mes', () async {
      final repository = LocalTrainingPlanRepository();
      await repository.saveVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 7),
          plan: TrainingPlan.byDefault(),
        ),
      );
      await repository.saveVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 9),
          plan: TrainingPlan.byDefault(),
        ),
      );
      await repository.saveVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 7),
          plan: _junior1SixTwo(),
        ),
      );

      // Otra instancia: lo lee del almacenamiento, no de memoria.
      final plans = await LocalTrainingPlanRepository().getPlans();
      expect(plans.versions.map((v) => v.validFrom), [
        DateTime(2026, 7),
        DateTime(2026, 9),
      ]);
      expect(plans.currentIn(2026, 8), _junior1SixTwo());
    });
  });
}
