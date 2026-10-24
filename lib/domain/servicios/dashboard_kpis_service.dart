import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';

class DashboardCumplimientoAcumulado {
  final double horasValidas;
  final double horasObjetivo;
  final double cumplimiento;

  const DashboardCumplimientoAcumulado({
    required this.horasValidas,
    required this.horasObjetivo,
    required this.cumplimiento,
  });
}

class DashboardKpis {
  final int colaboradores;
  final int capacitandose;
  final int mesesEvaluados;
  final double horasValidas;
  final double horasObjetivo;
  final double horasDeclaradas;
  final double cumplimiento;
  final double ritmoMensual;
  final double proyeccionAnual;

  /// Objetivo de un año por colaborador, al ritmo de objetivo del período.
  /// Sale del plan de cada seniority: no es un valor fijo.
  final double metaAnualPorPersona;
  const DashboardKpis({
    required this.colaboradores,
    required this.capacitandose,
    required this.mesesEvaluados,
    required this.horasValidas,
    required this.horasObjetivo,
    required this.horasDeclaradas,
    required this.cumplimiento,
    required this.ritmoMensual,
    required this.proyeccionAnual,
    required this.metaAnualPorPersona,
  });
}

/// Cálculo extraído sin cambios de DashboardKpiGrid, compartido con el asistente.
class DashboardKpisService {
  const DashboardKpisService();

  DashboardCumplimientoAcumulado acumularCumplimiento(
    Iterable<ResumenEquiposPeriodo> meses,
  ) {
    var horasValidas = 0.0;
    var horasObjetivo = 0.0;
    for (final mes in meses) {
      if (!mes.tieneDatos || mes.colaboradores == 0) continue;
      // Las horas de cada mes ya respetan elegibilidad, categorías y topes.
      horasValidas += mes.horasRealizadas;
      horasObjetivo += mes.horasObjetivo;
    }
    return DashboardCumplimientoAcumulado(
      horasValidas: horasValidas,
      horasObjetivo: horasObjetivo,
      cumplimiento: _cumplimiento(horasValidas, horasObjetivo),
    );
  }

  double _cumplimiento(double horasValidas, double horasObjetivo) =>
      horasObjetivo == 0 ? 0 : horasValidas / horasObjetivo * 100;

  DashboardKpis calcular({
    required List<CumplimientoEmpleado> cumplimientos,
    required List<CargaDeHorasCRM> cargas,
    required int mesesEvaluados,
  }) {
    final legajos = {for (final item in cumplimientos) item.empleado.legajo};
    final totalEmpleados = legajos.length;
    final horasRealizadas = cumplimientos.fold<double>(
      0,
      (t, i) => t + i.totalHorasCompletadas,
    );
    final horasObjetivo = cumplimientos.fold<double>(
      0,
      (t, i) => t + i.totalHorasRequeridas,
    );
    final meses = mesesEvaluados < 1 ? 1 : mesesEvaluados;
    final ritmo = totalEmpleados == 0
        ? 0.0
        : horasRealizadas / totalEmpleados / meses;
    // Mismo denominador que el ritmo, así la proyección y su meta comparan.
    final objetivoMensual = totalEmpleados == 0
        ? 0.0
        : horasObjetivo / totalEmpleados / meses;
    final cargasNomina = cargas
        .where((c) => legajos.contains(c.empleadoLegajo))
        .toList();
    return DashboardKpis(
      colaboradores: totalEmpleados,
      capacitandose: cargasNomina
          .where((c) => !c.esDictada)
          .map((c) => c.empleadoLegajo)
          .toSet()
          .length,
      mesesEvaluados: meses,
      horasValidas: horasRealizadas,
      horasObjetivo: horasObjetivo,
      horasDeclaradas: cargasNomina.fold<double>(
        0,
        (t, c) => t + c.horasTotales,
      ),
      cumplimiento: _cumplimiento(horasRealizadas, horasObjetivo),
      ritmoMensual: ritmo,
      proyeccionAnual: ritmo * 12,
      metaAnualPorPersona: objetivoMensual * 12,
    );
  }
}
