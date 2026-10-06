import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_grid.dart';
import 'package:flutter/material.dart';

class EquiposKpiSection extends StatelessWidget {
  final int totalEquipos;
  final int totalColaboradores;
  final double horasRealizadas;
  final double horasObjetivo;
  final double desvioHoras;
  final double cumplimientoGlobal;
  final bool esAnual;

  const EquiposKpiSection({
    super.key,
    required this.totalEquipos,
    required this.totalColaboradores,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.desvioHoras,
    required this.cumplimientoGlobal,
    this.esAnual = false,
  });

  @override
  Widget build(BuildContext context) {
    // Leandro: llama a KpiGrid para mostrar los indicadores globales del período.
    return KpiGrid(
      items: [
        KpiData(
          title: 'Equipos activos',
          value: '$totalEquipos',
          detail: 'en seguimiento',
          help: esAnual
              ? 'Equipos con colaboradores elegibles en al menos uno de los meses con datos del año.'
              : 'Equipos con colaboradores elegibles en el período seleccionado.',
          icon: Icons.groups_outlined,
          color: equiposBrand,
        ),
        KpiData(
          title: 'Colaboradores',
          value: '$totalColaboradores',
          detail: 'en todos los equipos',
          help: esAnual
              ? 'Colaboradores elegibles al último período con datos disponible del año.'
              : 'Colaboradores que ya ingresaron y estaban activos al cierre del período seleccionado.',
          icon: Icons.people_outline,
          color: const Color(0xFF0E7490),
        ),
        KpiData(
          title: 'Horas realizadas',
          value: horasRealizadas.toStringAsFixed(1),
          // Leandro: llama a _formatDesvio para expresar las horas faltantes o excedentes.
          detail: _formatDesvio(desvioHoras),
          help: esAnual
              ? 'Suma de las horas válidas de los meses con datos del año.'
              : 'Horas CRM de cursos finalizados en LMS, limitadas por la carga máxima del curso y por el objetivo de cada categoría según seniority.',
          icon: Icons.schedule_outlined,
          color: desvioHoras >= 0
              ? const Color(0xFF16A34A)
              : const Color(0xFF6941C6),
        ),
        KpiData(
          title: 'Cumplimiento global',
          value: '${cumplimientoGlobal.toStringAsFixed(1)}%',
          detail: cumplimientoGlobal >= 100
              ? 'objetivo alcanzado'
              : 'avance acumulado',
          help: esAnual
              ? 'Porcentaje de horas válidas acumuladas sobre la suma de los objetivos mensuales de los períodos con datos.'
              : 'Porcentaje de horas válidas realizadas sobre las horas objetivo del período.',
          icon: Icons.trending_up,
          color: cumplimientoGlobal >= 100
              ? const Color(0xFF16A34A)
              : const Color(0xFFD97706),
        ),
      ],
    );
  }

  String _formatDesvio(double desvioHoras) {
    if (desvioHoras >= 0) {
      return '+${desvioHoras.toStringAsFixed(1)} hs sobre objetivo';
    }

    return 'faltan ${desvioHoras.abs().toStringAsFixed(1)} hs';
  }
}
