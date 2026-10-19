import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/servicios/dashboard_kpis_service.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (error != null) return Text('Error: ${error.error}');

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
    final cumplimientoGlobal = kpis.cumplimiento;
    final mesesDelPeriodo = kpis.mesesEvaluados;
    final ritmoMensual = kpis.ritmoMensual;
    final proyeccionAnual = kpis.proyeccionAnual;
    final empleadosTomaronCurso = kpis.capacitandose;
    final horasDeclaradasPeriodo = kpis.horasDeclaradas;
    final metaPeriodo = kpis.horasObjetivo;
    const nombresMeses = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    final periodoLabel = alcance == AlcancePeriodo.anual
        ? 'AÑO $anioSeleccionado'
        : '${nombresMeses[mesSeleccionado - 1]} $anioSeleccionado';

    final cards = [
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
        footer: '${totalEmpleados - empleadosTomaronCurso} sin cursos tomados',
        icon: Icons.school_outlined,
        color: context.colores.exito.texto,
      ),
      DashboardKpiCard(
        title: 'HORAS DECLARADAS CRM · $periodoLabel',
        value: '${horasDeclaradasPeriodo.toStringAsFixed(1)} h',
        suffix: 'declaradas',
        progress: metaPeriodo == 0
            ? 0
            : (horasDeclaradasPeriodo / metaPeriodo).clamp(0.0, 1.0),
        progressLabel: alcance == AlcancePeriodo.anual
            ? 'Meta: ${metaPeriodo.toStringAsFixed(0)} h en $mesesDelPeriodo ${mesesDelPeriodo == 1 ? 'mes' : 'meses'} con datos'
            : 'Meta: ${metaPeriodo.toStringAsFixed(0)} h según seniority',
        footer:
            '${(metaPeriodo - horasDeclaradasPeriodo).clamp(0, double.infinity).toStringAsFixed(1)} h para la meta',
        secondaryText:
            '${horasRealizadas.toStringAsFixed(1)} h válidas para el objetivo',
        icon: Icons.schedule_outlined,
        color: context.colorScheme.primary,
      ),
      DashboardKpiCard(
        title: 'PROYECCIÓN ANUAL',
        value: '${proyeccionAnual.toStringAsFixed(0)} h',
        suffix: '/ Meta: 96 h',
        progress: (proyeccionAnual / 96).clamp(0.0, 1.0),
        progressLabel: 'Ritmo actual: ${ritmoMensual.toStringAsFixed(1)} h/mes',
        footer: 'Cumplimiento global ${cumplimientoGlobal.toStringAsFixed(0)}%',
        icon: Icons.trending_up,
        color: context.colorScheme.primary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 156,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

class DashboardKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String suffix;
  final double progress;
  final String progressLabel;
  final String footer;
  final String? secondaryText;
  final IconData icon;
  final Color color;

  const DashboardKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.suffix,
    required this.progress,
    required this.progressLabel,
    required this.footer,
    this.secondaryText,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: context.panel(sombra: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          if (secondaryText != null) ...[
            const SizedBox(height: 3),
            Text(
              secondaryText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.colores.exito.texto,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  suffix,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.colores.graficoPista,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
