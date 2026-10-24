import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/widgets/shared/comparacion_moodle_crm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CumplimientoEmpleado _c({
  required Map<TipoCurso, double> moodle,
  required Map<TipoCurso, double> crm,
  String legajo = '1',
}) {
  return CumplimientoEmpleado(
    empleado: Empleado(
      legajo: legajo,
      nombre: 'Ana',
      apellido: 'Pérez',
      seniority: Seniority.senior1,
      area: 'SERVICIOS',
      mail: '$legajo@finnegans.com',
      equipo: 'SOPORTE',
    ),
    horasValidas: moodle,
    horasDeclaradas: crm,
    horasRequeridas: {for (final tipo in TipoCurso.values) tipo: 4},
  );
}

final _items = [
  _c(
    moodle: {
      TipoCurso.habilidadesDeNegocio: 8,
      TipoCurso.habilidadesBlandas: 2,
      // Libres válidas vienen del CRM: no son horas de Moodle.
      TipoCurso.libresExploracion: 3,
    },
    crm: {
      TipoCurso.habilidadesDeNegocio: 10,
      TipoCurso.habilidadesBlandas: 4,
      TipoCurso.libresExploracion: 3,
      TipoCurso.dictadoCapacitaciones: 5,
    },
  ),
  _c(
    legajo: '2',
    moodle: {TipoCurso.habilidadesDeNegocio: 4},
    crm: {TipoCurso.habilidadesDeNegocio: 2},
  ),
];

void main() {
  test('Suma Moodle solo en Negocio y Blandas y CRM en las 4', () {
    final comparacion = ComparacionMoodleCrm.desde(_items);

    expect(comparacion.moodle, {
      TipoCurso.habilidadesDeNegocio: 12,
      TipoCurso.habilidadesBlandas: 2,
    });
    expect(comparacion.totalMoodle(ComparacionMoodleCrm.comparables), 14);
    expect(comparacion.totalCrm(ComparacionMoodleCrm.comparables), 16);
    expect(comparacion.totalCrm(TipoCurso.values), 24);
  });

  for (final ancho in [1200.0, 500.0]) {
    testWidgets('Las cards se muestran sin desbordes a $ancho px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ComparacionMoodleCrmCards(cumplimientos: _items),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('comparacion_comparables')), findsOne);
      expect(find.byKey(const Key('comparacion_total')), findsOne);
      // Moodle solo aparece en la comparación; la otra card es solo CRM.
      expect(find.text('14.0 h'), findsOne);
      // Negocio es 12 de las 24 h de CRM.
      expect(find.text('Negocio\n50%'), findsOne);
      expect(find.text('16.0 h'), findsOne);
      expect(find.text('24.0 h'), findsOne);
      expect(find.textContaining('CRM registra 2.0 h más'), findsOne);
      expect(tester.takeException(), isNull);
    });
  }
}
