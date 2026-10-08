import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_grid.dart';
import 'package:flutter/material.dart';

class AreasKpiSection extends StatelessWidget {
  final int totalAreas;
  final int totalColaboradores;
  final double horasRealizadas;
  final double horasObjetivo;
  final double desvioHoras;
  final double cumplimientoGlobal;
  final bool esAnual;

  const AreasKpiSection({
    super.key,
    required this.totalAreas,
    required this.totalColaboradores,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.desvioHoras,
    required this.cumplimientoGlobal,
    this.esAnual = false,
  });

  @override
  Widget build(BuildContext context) {
    return KpiGrid(
      items: [
        KpiData(
          title: 'Áreas activas',
          value: '$totalAreas',
          detail: 'en seguimiento',
          help: esAnual
              ? 'Áreas con colaboradores elegibles en al menos uno de los meses con datos del año.'
              : 'Áreas con colaboradores elegibles en el período seleccionado.',
          icon: Icons.apartment_outlined,
          color: areasBrand,
        ),
        KpiData(
          title: 'Colaboradores',
          value: '$totalColaboradores',
          detail: 'en todas las áreas',
          help: esAnual
              ? 'Colaboradores únicos que fueron elegibles en al menos uno de los meses con datos del año.'
              : 'Colaboradores elegibles en el período seleccionado.',
          icon: Icons.people_outline,
          color: const Color(0xFF0E7490),
        ),
        KpiData(
          title: 'Horas realizadas',
          value: horasRealizadas.toStringAsFixed(1),
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
