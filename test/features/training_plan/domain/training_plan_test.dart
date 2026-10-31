import 'dart:convert';

import 'package:app_finnegans/features/training_plan/data/in_memory_training_plan_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';

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
        : TrainingPlanDefaults.hours[seniority]!,
});

void main() {
  const service = TrainingPlanService();

  group('PlanFormacion', () {
    test('el plan por defecto es la tabla del enum Seniority', () {
      const plan = TrainingPlanDefaults.plan;

      for (final seniority in Seniority.values) {
        expect(plan.hours[seniority], TrainingPlanDefaults.hours[seniority]!);
      }
      expect(plan.hours[Seniority.semisenior3], {
        CourseCategory.businessSkills: 1,
        CourseCategory.softSkills: 4,
        CourseCategory.exploration: 1,
        CourseCategory.teaching: 2,
      });
      expect(service.total(plan, Seniority.manager), 8);
    });

    test('el total de cada seniority es libre', () {
      final plan = service.validate(
        TrainingPlan({
          for (final seniority in Seniority.values)
            seniority: seniority == Seniority.trainee
                ? {
                    CourseCategory.businessSkills: 6,
                    CourseCategory.softSkills: 4,
                    CourseCategory.exploration: 0,
                    CourseCategory.teaching: 0,
                  }
                : TrainingPlanDefaults.hours[seniority]!,
        }),
      );

      expect(service.total(plan, Seniority.trainee), 10);
      expect(service.total(plan, Seniority.junior1), 8);
    });

    test('rechaza un plan incompleto o con horas inválidas', () {
      Map<Seniority, Map<CourseCategory, double>> withJunior1(
        Map<CourseCategory, double> hours,
      ) => {
        for (final seniority in Seniority.values)
          seniority: seniority == Seniority.junior1
              ? hours
              : TrainingPlanDefaults.hours[seniority]!,
      };

      expect(
        () => service.validate(
          TrainingPlan({
            Seniority.trainee: TrainingPlanDefaults.hours[Seniority.trainee]!,
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => service.validate(
          TrainingPlan(
            withJunior1({
              CourseCategory.businessSkills: 4,
              CourseCategory.softSkills: 4,
              CourseCategory.exploration: 0,
            }),
          ),
        ),
        throwsFormatException,
      );
      for (final invalid in [-1.0, double.nan, double.infinity, 161.0]) {
        expect(
          () => service.validate(
            TrainingPlan(
              withJunior1({
                CourseCategory.businessSkills: invalid,
                CourseCategory.softSkills: 4,
                CourseCategory.exploration: 0,
                CourseCategory.teaching: 0,
              }),
            ),
          ),
          throwsFormatException,
          reason: '$invalid',
        );
      }
    });

    test('el error indica la seniority, la categoría y el problema', () {
      final error = () {
        try {
          service.validate(
            TrainingPlan({
              for (final seniority in Seniority.values)
                seniority: seniority == Seniority.senior2
                    ? {
                        CourseCategory.businessSkills: 0,
                        CourseCategory.softSkills: -2,
                        CourseCategory.exploration: 2,
                        CourseCategory.teaching: 4,
                      }
                    : TrainingPlanDefaults.hours[seniority]!,
            }),
          );
        } on InvalidTrainingPlanException catch (error) {
          return error;
        }
        return null;
      }();
      expect(error?.seniority, Seniority.senior2);
      expect(error?.category, CourseCategory.softSkills);
      expect(error?.issue, HoursIssue.negative);
    });

    test('errorHoras aplica la misma regla, campo por campo', () {
      expect(service.hoursIssue(null), isNotNull);
      expect(service.hoursIssue(-0.5), isNotNull);
      expect(service.hoursIssue(160.5), isNotNull);
      expect(service.hoursIssue(0), isNull);
      expect(service.hoursIssue(2.5), isNull);
      expect(service.hoursIssue(160), isNull);
    });

    test('se compara por valor y sobrevive al JSON', () {
      final plan = _junior1SixTwo();
      final copy = TrainingPlan.fromJson(
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>,
      );

      expect(copy, plan);
      expect(copy.hashCode, plan.hashCode);
      expect(copy, isNot(TrainingPlanDefaults.plan));
    });
  });

  group('PlanesFormacion', () {
    final july = service.version(
      validFrom: DateTime(2026, 7, 15),
      plan: _junior1SixTwo(),
    );

    test('la vigencia se normaliza al primer día del mes', () {
      expect(july.validFrom, DateTime(2026, 7));
    });

    test('antes de la primera versión rige el plan por defecto', () {
      final plans = service.history([july]);

      expect(service.currentIn(plans, 2026, 6), TrainingPlanDefaults.plan);
      expect(service.currentVersionIn(plans, 2026, 6), isNull);
      expect(
        service.currentIn(const TrainingPlanHistory.empty(), 2026, 7),
        TrainingPlanDefaults.plan,
      );
    });

    test('cada mes usa la última versión que ya empezó', () {
      final october = TrainingPlanVersion(
        validFrom: DateTime(2026, 10),
        plan: TrainingPlanDefaults.plan,
      );
      // Desordenadas a propósito.
      final plans = service.history([october, july]);

      expect(plans.versions.map((v) => v.validFrom), [
        DateTime(2026, 7),
        DateTime(2026, 10),
      ]);
      expect(service.currentIn(plans, 2026, 7), july.plan);
      expect(service.currentIn(plans, 2026, 9), july.plan);
      expect(service.currentIn(plans, 2026, 10), TrainingPlanDefaults.plan);
      expect(service.currentIn(plans, 2027, 3), TrainingPlanDefaults.plan);
    });

    test('dos versiones del mismo mes son un error', () {
      expect(() => service.history([july, july]), throwsFormatException);
    });

    test('conVersion reemplaza la del mismo mes', () {
      final plans = service.withVersion(
        service.history([july]),
        TrainingPlanVersion(
          validFrom: DateTime(2026, 7),
          plan: TrainingPlanDefaults.plan,
        ),
      );

      expect(plans.versions, hasLength(1));
      expect(service.currentIn(plans, 2026, 8), TrainingPlanDefaults.plan);
    });

    test('el plan vigente hoy usa el reloj inyectado', () {
      final plans = service.history([july]);
      expect(
        TrainingPlanService(now: () => DateTime(2026, 6, 30)).current(plans),
        TrainingPlanDefaults.plan,
      );
      expect(
        TrainingPlanService(now: () => DateTime(2026, 8, 1)).current(plans),
        july.plan,
      );
    });

    test('el objetivo anual suma los 12 meses con su versión', () {
      final plans = service.history([july]);

      // Enero a junio 4/4 por defecto, julio a diciembre 6/2.
      expect(service.requiredForYear(plans, Seniority.junior1, 2026), {
        CourseCategory.businessSkills: 6 * 4.0 + 6 * 6.0,
        CourseCategory.softSkills: 6 * 4.0 + 6 * 2.0,
        CourseCategory.exploration: 0.0,
        CourseCategory.teaching: 0.0,
      });
      // Sin cambios es el plan mensual × 12.
      expect(
        service.requiredForYear(plans, Seniority.senior1, 2026),
        TrainingPlanDefaults.hours[Seniority.senior1]!.map(
          (type, h) => MapEntry(type, h * 12),
        ),
      );
    });
  });

  group('InMemoryTrainingPlanRepository', () {
    test('sin nada guardado no hay versiones', () async {
      final plans = await InMemoryTrainingPlanRepository().getPlans();

      expect(plans.versions, isEmpty);
    });

    test('guarda versiones y reemplaza la del mismo mes', () async {
      final repository = InMemoryTrainingPlanRepository();
      await repository.saveVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 7),
          plan: TrainingPlanDefaults.plan,
        ),
      );
      await repository.saveVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 9),
          plan: TrainingPlanDefaults.plan,
        ),
      );
      await repository.saveVersion(
        TrainingPlanVersion(
          validFrom: DateTime(2026, 7),
          plan: _junior1SixTwo(),
        ),
      );

      final plans = await repository.getPlans();
      expect(plans.versions.map((v) => v.validFrom), [
        DateTime(2026, 7),
        DateTime(2026, 9),
      ]);
      expect(service.currentIn(plans, 2026, 8), _junior1SixTwo());
    });

    test('rechaza guardar un plan inválido', () async {
      expect(
        InMemoryTrainingPlanRepository().saveVersion(
          TrainingPlanVersion(
            validFrom: DateTime(2026, 7),
            plan: const TrainingPlan({}),
          ),
        ),
        throwsFormatException,
      );
    });
  });
}
