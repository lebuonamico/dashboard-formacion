import 'dart:convert';

import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/domain/modelos/plan_formacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El plan por defecto con Junior 1 en 6 h de negocio y 2 de blandas.
PlanFormacion _junior1SeisDos() => PlanFormacion({
  for (final seniority in Seniority.values)
    seniority: seniority == Seniority.junior1
        ? {
            TipoCurso.habilidadesDeNegocio: 6,
            TipoCurso.habilidadesBlandas: 2,
            TipoCurso.libresExploracion: 0,
            TipoCurso.dictadoCapacitaciones: 0,
          }
        : seniority.planFormacion,
});

void main() {
  group('PlanFormacion', () {
    test('el plan por defecto es la tabla del enum Seniority', () {
      final plan = PlanFormacion.porDefecto();

      for (final seniority in Seniority.values) {
        expect(plan.horasRequeridas(seniority), seniority.planFormacion);
      }
      expect(plan.horasRequeridas(Seniority.semisenior3), {
        TipoCurso.habilidadesDeNegocio: 1,
        TipoCurso.habilidadesBlandas: 4,
        TipoCurso.libresExploracion: 1,
        TipoCurso.dictadoCapacitaciones: 2,
      });
      expect(plan.total(Seniority.manager), 8);
    });

    test('el total de cada seniority es libre', () {
      final plan = PlanFormacion({
        for (final seniority in Seniority.values)
          seniority: seniority == Seniority.trainee
              ? {
                  TipoCurso.habilidadesDeNegocio: 6,
                  TipoCurso.habilidadesBlandas: 4,
                  TipoCurso.libresExploracion: 0,
                  TipoCurso.dictadoCapacitaciones: 0,
                }
              : seniority.planFormacion,
      });

      expect(plan.total(Seniority.trainee), 10);
      expect(plan.total(Seniority.junior1), 8);
    });

    test('rechaza un plan incompleto o con horas inválidas', () {
      Map<Seniority, Map<TipoCurso, double>> conJunior1(
        Map<TipoCurso, double> horas,
      ) => {
        for (final seniority in Seniority.values)
          seniority: seniority == Seniority.junior1
              ? horas
              : seniority.planFormacion,
      };

      expect(
        () =>
            PlanFormacion({Seniority.trainee: Seniority.trainee.planFormacion}),
        throwsFormatException,
      );
      expect(
        () => PlanFormacion(
          conJunior1({
            TipoCurso.habilidadesDeNegocio: 4,
            TipoCurso.habilidadesBlandas: 4,
            TipoCurso.libresExploracion: 0,
          }),
        ),
        throwsFormatException,
      );
      for (final invalido in [-1.0, double.nan, double.infinity, 161.0]) {
        expect(
          () => PlanFormacion(
            conJunior1({
              TipoCurso.habilidadesDeNegocio: invalido,
              TipoCurso.habilidadesBlandas: 4,
              TipoCurso.libresExploracion: 0,
              TipoCurso.dictadoCapacitaciones: 0,
            }),
          ),
          throwsFormatException,
          reason: '$invalido',
        );
      }
    });

    test('errorHoras aplica la misma regla, campo por campo', () {
      expect(PlanFormacion.errorHoras(null), isNotNull);
      expect(PlanFormacion.errorHoras(-0.5), isNotNull);
      expect(PlanFormacion.errorHoras(160.5), isNotNull);
      expect(PlanFormacion.errorHoras(0), isNull);
      expect(PlanFormacion.errorHoras(2.5), isNull);
      expect(PlanFormacion.errorHoras(160), isNull);
    });

    test('se compara por valor y sobrevive al JSON', () {
      final plan = _junior1SeisDos();
      final copia = PlanFormacion.fromJson(
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>,
      );

      expect(copia, plan);
      expect(copia.hashCode, plan.hashCode);
      expect(copia, isNot(PlanFormacion.porDefecto()));
    });
  });

  group('PlanesFormacion', () {
    final julio = VersionPlanFormacion(
      vigenteDesde: DateTime(2026, 7, 15),
      plan: _junior1SeisDos(),
    );

    test('la vigencia se normaliza al primer día del mes', () {
      expect(julio.vigenteDesde, DateTime(2026, 7));
    });

    test('antes de la primera versión rige el plan por defecto', () {
      final planes = PlanesFormacion([julio]);

      expect(planes.vigenteEn(2026, 6), PlanFormacion.porDefecto());
      expect(planes.versionVigenteEn(2026, 6), isNull);
      expect(
        const PlanesFormacion.sinVersiones().vigenteEn(2026, 7),
        PlanFormacion.porDefecto(),
      );
    });

    test('cada mes usa la última versión que ya empezó', () {
      final octubre = VersionPlanFormacion(
        vigenteDesde: DateTime(2026, 10),
        plan: PlanFormacion.porDefecto(),
      );
      // Desordenadas a propósito.
      final planes = PlanesFormacion([octubre, julio]);

      expect(planes.versiones.map((v) => v.vigenteDesde), [
        DateTime(2026, 7),
        DateTime(2026, 10),
      ]);
      expect(planes.vigenteEn(2026, 7), julio.plan);
      expect(planes.vigenteEn(2026, 9), julio.plan);
      expect(planes.vigenteEn(2026, 10), PlanFormacion.porDefecto());
      expect(planes.vigenteEn(2027, 3), PlanFormacion.porDefecto());
    });

    test('dos versiones del mismo mes son un error', () {
      expect(() => PlanesFormacion([julio, julio]), throwsFormatException);
    });

    test('conVersion reemplaza la del mismo mes', () {
      final planes = PlanesFormacion([julio]).conVersion(
        VersionPlanFormacion(
          vigenteDesde: DateTime(2026, 7),
          plan: PlanFormacion.porDefecto(),
        ),
      );

      expect(planes.versiones, hasLength(1));
      expect(planes.vigenteEn(2026, 8), PlanFormacion.porDefecto());
    });

    test('el objetivo anual suma los 12 meses con su versión', () {
      final planes = PlanesFormacion([julio]);

      // Enero a junio 4/4 por defecto, julio a diciembre 6/2.
      expect(planes.requeridasDelAnio(Seniority.junior1, 2026), {
        TipoCurso.habilidadesDeNegocio: 6 * 4.0 + 6 * 6.0,
        TipoCurso.habilidadesBlandas: 6 * 4.0 + 6 * 2.0,
        TipoCurso.libresExploracion: 0.0,
        TipoCurso.dictadoCapacitaciones: 0.0,
      });
      // Sin cambios es el plan mensual × 12.
      expect(
        planes.requeridasDelAnio(Seniority.senior1, 2026),
        Seniority.senior1.planFormacion.map(
          (tipo, h) => MapEntry(tipo, h * 12),
        ),
      );
    });
  });

  group('LocalPlanFormacionRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sin nada guardado no hay versiones', () async {
      final planes = await LocalPlanFormacionRepository().getPlanes();

      expect(planes.versiones, isEmpty);
    });

    test('guarda versiones y reemplaza la del mismo mes', () async {
      final repositorio = LocalPlanFormacionRepository();
      await repositorio.guardarVersion(
        VersionPlanFormacion(
          vigenteDesde: DateTime(2026, 7),
          plan: PlanFormacion.porDefecto(),
        ),
      );
      await repositorio.guardarVersion(
        VersionPlanFormacion(
          vigenteDesde: DateTime(2026, 9),
          plan: PlanFormacion.porDefecto(),
        ),
      );
      await repositorio.guardarVersion(
        VersionPlanFormacion(
          vigenteDesde: DateTime(2026, 7),
          plan: _junior1SeisDos(),
        ),
      );

      // Otra instancia: lo lee del almacenamiento, no de memoria.
      final planes = await LocalPlanFormacionRepository().getPlanes();
      expect(planes.versiones.map((v) => v.vigenteDesde), [
        DateTime(2026, 7),
        DateTime(2026, 9),
      ]);
      expect(planes.vigenteEn(2026, 8), _junior1SeisDos());
    });
  });
}
