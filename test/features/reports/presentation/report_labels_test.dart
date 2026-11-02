import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/domain/training_report_builder.dart';
import 'package:app_finnegans/features/reports/presentation/report_labels.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingReport _report({
  ReportType type = ReportType.area,
  String title = 'Desarrollo',
  String period = 'Octubre 2026',
  String? area,
  String? leaders,
  int? areaCount,
  int? teamCount,
  int? trainingCount,
}) => const TrainingReportBuilder().build(
  type: type,
  title: title,
  period: period,
  memberCount: 12,
  onTarget: 0,
  hours: 0,
  target: 0,
  percentage: 0,
  level: ReportLevel.critical,
  area: area,
  leaders: leaders,
  areaCount: areaCount,
  teamCount: teamCount,
  trainingCount: trainingCount,
  members: const [],
);

void main() {
  test('El nombre del archivo no lleva tildes, eñes ni símbolos', () {
    final report = _report(
      title: 'Diseño & Núñez',
      period: 'Año 2026 · meses con datos',
    );

    expect(
      reportFileName(report),
      'reporte_de_area_diseno_nunez_ano_2026_meses_con_datos.pdf',
    );
  });

  test('Un símbolo al final del título no deja un guion bajo suelto', () {
    expect(
      reportFileName(_report(title: '¡Ventas!', period: '(Octubre 2026)')),
      'reporte_de_area_ventas_octubre_2026.pdf',
    );
  });

  test('El tipo decide el título del desglose', () {
    expect(ReportType.general.breakdownTitle, 'Cumplimiento por área');
    expect(ReportType.area.breakdownTitle, 'Cumplimiento por equipo');
    expect(ReportType.team.breakdownTitle, isNull);
  });

  test('El estado usa los textos del semáforo de la app', () {
    expect(ReportLevel.values.map((level) => level.label), [
      'En objetivo',
      'En riesgo',
      'Crítico',
    ]);
  });

  group('Líneas bajo el título', () {
    test('General: áreas, equipos y cuántos se capacitan', () {
      expect(
        reportDetails(
          _report(
            type: ReportType.general,
            areaCount: 3,
            teamCount: 6,
            trainingCount: 9,
          ),
        ),
        ['3 áreas · 6 equipos', '9 de 12 capacitándose'],
      );
    });

    test('Área: el líder solo si tiene, y los equipos', () {
      expect(reportDetails(_report(leaders: 'Ana Pérez', teamCount: 2)), [
        'Líder: Ana Pérez',
        '2 equipos',
      ]);
      expect(reportDetails(_report(leaders: '  ', teamCount: 1)), [
        '1 equipos',
      ]);
    });

    test('Equipo: el área y el líder', () {
      expect(
        reportDetails(
          _report(type: ReportType.team, area: 'Desarrollo', leaders: 'Ana'),
        ),
        ['Área: Desarrollo', 'Líder: Ana'],
      );
    });
  });
}
