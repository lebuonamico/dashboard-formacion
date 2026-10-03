import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_grid.dart';
import 'package:flutter/material.dart';

/// Leandro: Traduce el resumen del período a tarjetas del KpiGrid compartido.
class EquiposKpiSection extends StatelessWidget {
  final int totalEquipos;
  final int totalColaboradores;
  final double horasRealizadas;
  final double horasObjetivo;
  final double desvioHoras;
  final double cumplimientoGlobal;

  const EquiposKpiSection({
    super.key,
    required this.totalEquipos,
    required this.totalColaboradores,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.desvioHoras,
    required this.cumplimientoGlobal,
  });

  @override
  Widget build(BuildContext context) {
    return KpiGrid(
      items: [
        KpiData(
          title: 'Equipos activos',
          value: '$totalEquipos',
          detail: 'en seguimiento',
          help:
              'Equipos con al menos una carga CRM o una finalización LMS en el período seleccionado.',
          icon: Icons.groups_outlined,
          color: equiposBrand,
        ),
        KpiData(
          title: 'Colaboradores',
          value: '$totalColaboradores',
          detail: 'en todos los equipos',
          help:
              'Integrantes de la nómina actual pertenecientes a los equipos activos del período.',
          icon: Icons.people_outline,
          color: const Color(0xFF0E7490),
        ),
        KpiData(
          title: 'Horas realizadas',
          value: horasRealizadas.toStringAsFixed(1),
          detail: _formatDesvio(desvioHoras),
          help:
              'Horas CRM de cursos finalizados en LMS, limitadas por la carga máxima del curso y por el objetivo de cada categoría según seniority.',
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
          help:
              'Horas realizadas totales dividido horas objetivo totales. No es un promedio simple de equipos.',
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
