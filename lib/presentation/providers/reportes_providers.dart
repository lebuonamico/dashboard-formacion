import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/domain/servicios/dashboard_kpis_service.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/reportes/reporte_pdf.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Arman el reporte de cada pantalla con los mismos cálculos que sus cards.
// `null` cuando el período no tiene nada para reportar.

final reporteDashboardProvider = FutureProvider<ReporteFormacion?>((ref) async {
  final periodo = _periodo(ref);
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) return null;
  final cumplimientos = await ref.watch(cumplimientoDashboardProvider.future);
  if (cumplimientos.isEmpty) return null;

  final cargas = await ref.watch(cargasDashboardProvider.future);
  final mesesEvaluados = await ref.watch(
    mesesEvaluadosDashboardProvider.future,
  );
  final areas = await ref.watch(semaforoPorAreaProvider.future);
  final equipos = await ref.watch(teamOverviewsProvider.future);
  final evolucion = await ref.watch(evolucionMensualDashboardProvider.future);
  final proyeccion = await _proyeccionOpcional(ref, (area: null, equipo: null));

  final kpis = const DashboardKpisService().calcular(
    cumplimientos: cumplimientos,
    cargas: cargas,
    mesesEvaluados: mesesEvaluados,
  );
  final estado = EstadoSemaforo.desdePorcentaje(kpis.cumplimiento);
  return ReporteFormacion(
    tipo: TipoReporte.general,
    titulo: 'Plan de formación interna',
    detalles: [
      '${areas.length} áreas · ${equipos.length} equipos',
      '${kpis.capacitandose} de ${kpis.colaboradores} capacitándose',
    ],
    periodo: periodo,
    integrantes: kpis.colaboradores,
    enObjetivo: _enObjetivo(cumplimientos),
    horas: kpis.horasValidas,
    objetivo: kpis.horasObjetivo,
    porcentaje: kpis.cumplimiento,
    estado: estado.label,
    nivel: _nivelSemaforo(estado),
    proyeccion: proyeccion,
    miembros: cumplimientos,
    desglose: [
      for (final area in areas)
        FilaDesgloseReporte(
          nombre: area.area,
          integrantes: area.cantidadColaboradores,
          horas: area.horasCompletadas,
          objetivo: area.horasRequeridas,
          porcentaje: area.porcentajeCumplimiento,
          estado: area.semaforo.label,
          nivel: _nivelSemaforo(area.semaforo),
        ),
    ],
    evolucion: evolucion,
  );
});

final reporteAreaProvider = FutureProvider.family<ReporteFormacion?, String>((
  ref,
  nombreArea,
) async {
  final periodo = _periodo(ref);
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) return null;
  final detalle = await ref.watch(detalleAreaProvider(nombreArea).future);
  if (detalle == null) return null;

  final area = detalle.area;
  final proyeccion = await _proyeccionOpcional(ref, (
    area: area.nombre,
    equipo: null,
  ));
  return ReporteFormacion(
    tipo: TipoReporte.area,
    titulo: area.nombre,
    detalles: [
      if (area.lideres case final lideres? when lideres.trim().isNotEmpty)
        'Líder: $lideres',
      '${detalle.equipos.length} equipos',
    ],
    periodo: periodo,
    integrantes: area.cantidadIntegrantes,
    enObjetivo: area.integrantesEnObjetivo,
    horas: area.horasRealizadas,
    objetivo: area.horasObjetivo,
    porcentaje: area.porcentajeCumplimiento,
    estado: area.semaforo.label,
    nivel: _nivelSemaforo(area.semaforo),
    proyeccion: proyeccion,
    miembros: detalle.miembros,
    desglose: [
      for (final equipo in detalle.equipos)
        FilaDesgloseReporte(
          nombre: equipo.name,
          integrantes: equipo.memberCount,
          horas: equipo.completedHours,
          objetivo: equipo.targetHours,
          porcentaje: equipo.completionPercentage,
          estado: equipo.status.label,
          nivel: _nivelEquipo(equipo.status),
        ),
    ],
  );
});

final reporteEquipoProvider =
    FutureProvider.family<ReporteFormacion?, ({String area, String equipo})>((
      ref,
      seccion,
    ) async {
      final periodo = _periodo(ref);
      if (!await ref.watch(hasTeamPeriodDataProvider.future)) return null;
      final detalle = await ref.watch(
        teamDetailProvider(seccion).future,
      );
      if (detalle == null) return null;

      final equipo = detalle.overview;
      final proyeccion = await _proyeccionOpcional(ref, (
        area: equipo.area,
        equipo: equipo.name,
      ));
      return ReporteFormacion(
        tipo: TipoReporte.equipo,
        titulo: equipo.name,
        detalles: [
          'Área: ${equipo.area}',
          if (equipo.leader.trim().isNotEmpty) 'Líder: ${equipo.leader}',
        ],
        periodo: periodo,
        integrantes: equipo.memberCount,
        enObjetivo: equipo.membersOnTarget,
        horas: equipo.completedHours,
        objetivo: equipo.targetHours,
        porcentaje: equipo.completionPercentage,
        estado: equipo.status.label,
        nivel: _nivelEquipo(equipo.status),
        proyeccion: proyeccion,
        miembros: detalle.members,
      );
    });

typedef ImprimirReporte = Future<void> Function(ReporteFormacion reporte);

/// Maqueta el PDF y abre el diálogo de impresión. Los tests lo reemplazan
/// para no depender de las fuentes ni del diálogo del sistema.
final imprimirReporteProvider = Provider<ImprimirReporte>((ref) {
  final impresion = ref.watch(impresionRepositoryProvider);
  return (reporte) async {
    // Se genera antes de abrir el diálogo, así un error llega a quien llamó.
    final bytes = await generarReportePdf(reporte);
    await impresion.imprimirPdf(bytes, nombreArchivo: reporte.nombreArchivo);
  };
});

String _periodo(Ref ref) => etiquetaPeriodoDetallada(
  ref.watch(alcancePeriodoProvider),
  ref.watch(filtroMesPeriodoProvider),
  ref.watch(filtroAnioPeriodoProvider),
);

/// La proyección es una tarjeta opcional: si falla, el reporte sale sin ella,
/// igual que la pantalla, que oculta la card.
Future<ProyeccionAnual?> _proyeccionOpcional(
  Ref ref,
  ({String? area, String? equipo}) seccion,
) async {
  try {
    return await ref.watch(proyeccionAnualProvider(seccion).future);
  } catch (_) {
    return null;
  }
}

/// En el anual, quien cambió de equipo figura una vez por etapa: se cuenta
/// una sola vez.
int _enObjetivo(List<CumplimientoEmpleado> miembros) => {
  for (final m in miembros)
    if (m.cumpleObjetivo) m.empleado.legajo,
}.length;

NivelReporte _nivelSemaforo(EstadoSemaforo estado) => switch (estado) {
  EstadoSemaforo.verde => NivelReporte.ok,
  EstadoSemaforo.amarillo => NivelReporte.atencion,
  EstadoSemaforo.rojo => NivelReporte.critico,
};

NivelReporte _nivelEquipo(TeamStatus estado) => switch (estado) {
  TeamStatus.onTarget => NivelReporte.ok,
  TeamStatus.atRisk => NivelReporte.atencion,
  TeamStatus.critical => NivelReporte.critico,
};
