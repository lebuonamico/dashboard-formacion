import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:app_finnegans/domain/servicios/dashboard_kpis_service.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/reportes/reporte_pdf.dart';

// Arman el reporte de cada pantalla con los mismos cálculos que sus cards.

NivelReporte _nivelSemaforo(EstadoSemaforo estado) => switch (estado) {
  EstadoSemaforo.verde => NivelReporte.ok,
  EstadoSemaforo.amarillo => NivelReporte.atencion,
  EstadoSemaforo.rojo => NivelReporte.critico,
};

NivelReporte _nivelEquipo(EstadoEquipo estado) => switch (estado) {
  EstadoEquipo.enObjetivo => NivelReporte.ok,
  EstadoEquipo.enRiesgo => NivelReporte.atencion,
  EstadoEquipo.critico => NivelReporte.critico,
};

int _enObjetivo(List<CumplimientoEmpleado> miembros) => {
  for (final m in miembros)
    if (m.cumpleObjetivo) m.empleado.legajo,
}.length;

ReporteFormacion reporteDashboard({
  required String periodo,
  required List<CumplimientoEmpleado> cumplimientos,
  required List<CargaDeHorasCRM> cargas,
  required int mesesEvaluados,
  required List<SemaforoAreaViewModel> areas,
  required int cantidadEquipos,
  required List<({DateTime mes, double horas})> evolucion,
  ProyeccionAnual? proyeccion,
}) {
  final kpis = const DashboardKpisService().calcular(
    cumplimientos: cumplimientos,
    cargas: cargas,
    mesesEvaluados: mesesEvaluados,
  );
  final estado = EstadoSemaforo.desdePorcentaje(kpis.cumplimiento);
  return ReporteFormacion(
    tipo: 'Reporte general',
    titulo: 'Plan de formación interna',
    detalles: [
      '${areas.length} áreas · $cantidadEquipos equipos',
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
    desgloseTitulo: 'Cumplimiento por área',
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
    soloCriticos: true,
  );
}

ReporteFormacion reporteArea({
  required String periodo,
  required DetalleAreaViewModel detalle,
  ProyeccionAnual? proyeccion,
}) {
  final area = detalle.area;
  return ReporteFormacion(
    tipo: 'Reporte de área',
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
    desgloseTitulo: 'Cumplimiento por equipo',
    desglose: [
      for (final equipo in detalle.equipos)
        FilaDesgloseReporte(
          nombre: equipo.nombre,
          integrantes: equipo.cantidadIntegrantes,
          horas: equipo.horasRealizadas,
          objetivo: equipo.horasObjetivo,
          porcentaje: equipo.porcentajeCumplimiento,
          estado: equipo.estado.label,
          nivel: _nivelEquipo(equipo.estado),
        ),
    ],
    mostrarEquipo: true,
  );
}

ReporteFormacion reporteEquipo({
  required String periodo,
  required DetalleEquipoGeneral detalle,
  ProyeccionAnual? proyeccion,
}) {
  final equipo = detalle.resumen;
  return ReporteFormacion(
    tipo: 'Reporte de equipo',
    titulo: equipo.nombre,
    detalles: [
      'Área: ${equipo.area}',
      if (equipo.lider.trim().isNotEmpty) 'Líder: ${equipo.lider}',
    ],
    periodo: periodo,
    integrantes: equipo.cantidadIntegrantes,
    enObjetivo: equipo.integrantesEnObjetivo,
    horas: equipo.horasRealizadas,
    objetivo: equipo.horasObjetivo,
    porcentaje: equipo.porcentajeCumplimiento,
    estado: equipo.estado.label,
    nivel: _nivelEquipo(equipo.estado),
    proyeccion: proyeccion,
    miembros: detalle.miembros,
  );
}
