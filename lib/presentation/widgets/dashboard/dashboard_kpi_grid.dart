import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/servicios/dashboard_kpis_service.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';

class DashboardKpiGrid extends StatelessWidget {
  final AsyncValue<List<CumplimientoEmpleado>> cumplimientosAsync;
  final AsyncValue<List<CargaDeHorasCRM>> cargasAsync;
  final AsyncValue<List<SemaforoAreaViewModel>> areasAsync;
  final AsyncValue<List<EquipoGlobalViewModel>> equiposAsync;
  final AlcancePeriodo alcance;
  final int mesSeleccionado;
  final int anioSeleccionado;

  /// Meses evaluados en el período: 1 en el mensual, los meses con datos en
  /// el anual. Sirve para pasar las horas del período a un ritmo mensual.
  final int mesesEvaluados;

  /// Proyección a fin de año de toda la nómina visible.
  final AsyncValue<ProyeccionAnual?> proyeccionAsync;

  /// Variación del cumplimiento de toda la nómina contra el mes anterior.
  final AsyncValue<VariacionCumplimiento?> variacionAsync;

  const DashboardKpiGrid({
    super.key,
    required this.cumplimientosAsync,
    required this.cargasAsync,
    required this.areasAsync,
    required this.equiposAsync,
    required this.alcance,
    required this.mesSeleccionado,
    required this.anioSeleccionado,
    this.mesesEvaluados = 1,
    this.proyeccionAsync = const AsyncData(null),
    this.variacionAsync = const AsyncData(null),
  });

  @override
  Widget build(BuildContext context) {
    if (cumplimientosAsync.isLoading ||
        cargasAsync.isLoading ||
        areasAsync.isLoading ||
        equiposAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final asyncValues = [
      cumplimientosAsync,
      cargasAsync,
      areasAsync,
      equiposAsync,
    ];
    final error = asyncValues.where((value) => value.hasError).firstOrNull;
    if (error != null) {
      return ErrorDataState(
        title: 'No pudimos cargar esta sección',
        error: error.error!,
        compact: true,
      );
    }

    final cumplimientos = cumplimientosAsync.value ?? [];
    final cargas = cargasAsync.value ?? [];
    final areas = areasAsync.value ?? [];
    final equipos = equiposAsync.value ?? [];
    if (cumplimientos.isEmpty) return const SizedBox.shrink();

    final kpis = const DashboardKpisService().calcular(
      cumplimientos: cumplimientos,
      cargas: cargas,
      mesesEvaluados: mesesEvaluados,
    );
    final totalEmpleados = kpis.colaboradores;
    final horasRealizadas = kpis.horasValidas;
    final empleadosTomaronCurso = kpis.capacitandose;
    final metaPeriodo = kpis.horasObjetivo;
    // Mientras carga, o si el año no tiene datos, no se muestra su card.
    final proyeccion = proyeccionAsync.value;
    final esAnual = alcance == AlcancePeriodo.anual;
    final periodoLabel = esAnual
        ? 'AÑO $anioSeleccionado'
        : '${nombreMes(mesSeleccionado).toUpperCase()} $anioSeleccionado';

    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'COLABORADORES',
          value: '$totalEmpleados',
          suffix: ' nómina activa',
          progress: 1,
          progressLabel: '${areas.length} áreas',
          footer: '${equipos.length} equipos',
          icon: Icons.groups_outlined,
          color: context.colorScheme.primary,
        ),
        DashboardKpiCard(
          title: 'COLABORADORES CAPACITÁNDOSE',
          value: '$empleadosTomaronCurso',
          suffix: ' de $totalEmpleados',
          progress: (empleadosTomaronCurso / totalEmpleados).clamp(0.0, 1.0),
          progressLabel:
              '${(empleadosTomaronCurso / totalEmpleados * 100).toStringAsFixed(0)}% de la nómina',
          footer:
              '${totalEmpleados - empleadosTomaronCurso} sin cursos tomados',
          icon: Icons.school_outlined,
          color: context.colores.exito.texto,
        ),
        // Solo las horas que suman al objetivo de cumplimiento del período.
        DashboardKpiCard(
          title: 'HORAS VÁLIDAS · $periodoLabel',
          value: '${horasRealizadas.toStringAsFixed(1)} h',
          suffix: 'para el objetivo',
          progress: metaPeriodo == 0
              ? 0
              : (horasRealizadas / metaPeriodo).clamp(0.0, 1.0),
          progressLabel: 'Meta: ${metaPeriodo.toStringAsFixed(0)} h',
          footer:
              '${(metaPeriodo - horasRealizadas).clamp(0, double.infinity).toStringAsFixed(1)} h para la meta',
          icon: Icons.schedule_outlined,
          color: context.colorScheme.primary,
        ),
        cumplimientoKpiCard(
          context,
          esAnual: esAnual,
          anio: anioSeleccionado,
          mes: mesSeleccionado,
          porcentaje: kpis.cumplimiento,
          variacion: variacionAsync.value,
        ),
        if (proyeccion != null) proyeccionKpiCard(context, proyeccion),
      ],
    );
  }
}
