import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/dashboard_kpis_service.dart';
import 'package:flutter_test/flutter_test.dart';

CumplimientoEmpleado _cumplimiento(
  String legajo, {
  required double requeridas,
  double validas = 0,
}) => CumplimientoEmpleado(
  empleado: Empleado(
    legajo: legajo,
    nombre: 'Nombre $legajo',
    apellido: '',
    seniority: Seniority.junior1,
    area: 'Área',
    mail: '$legajo@finnegans.com',
  ),
  horasValidas: {TipoCurso.habilidadesDeNegocio: validas},
  horasDeclaradas: const {},
  horasRequeridas: {TipoCurso.habilidadesDeNegocio: requeridas},
);

void main() {
  const servicio = DashboardKpisService();

  test('La meta anual sale del objetivo del plan, no de 96 h fijas', () {
    // Un plan de 8 h y otro de 10 h: 9 h por persona y mes.
    final kpis = servicio.calcular(
      cumplimientos: [
        _cumplimiento('1', requeridas: 8, validas: 8),
        _cumplimiento('2', requeridas: 10, validas: 4),
      ],
      cargas: const [],
      mesesEvaluados: 1,
    );

    expect(kpis.metaAnualPorPersona, 9 * 12);
    expect(kpis.proyeccionAnual, 6 * 12);
  });

  test('En el anual divide por los meses evaluados, igual que el ritmo', () {
    // Tres meses de 8 h acumulados en el objetivo de cada persona.
    final kpis = servicio.calcular(
      cumplimientos: [
        _cumplimiento('1', requeridas: 24, validas: 12),
        _cumplimiento('2', requeridas: 24, validas: 6),
      ],
      cargas: const [],
      mesesEvaluados: 3,
    );

    expect(kpis.metaAnualPorPersona, 96);
    expect(kpis.ritmoMensual, 3);
  });

  test('Sin colaboradores la meta es 0', () {
    final kpis = servicio.calcular(
      cumplimientos: const [],
      cargas: const [],
      mesesEvaluados: 1,
    );

    expect(kpis.metaAnualPorPersona, 0);
  });
}
