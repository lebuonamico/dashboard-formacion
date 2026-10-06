import 'package:app_finnegans/presentation/widgets/teams/team_donut_chart.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:flutter/material.dart';

class EquiposCategoryDistribution extends StatelessWidget {
  final double horasNegocio;
  final double horasBlandas;
  final double horasLibres;
  final double horasDictado;
  final bool esAnual;

  const EquiposCategoryDistribution({
    super.key,
    required this.horasNegocio,
    required this.horasBlandas,
    required this.horasLibres,
    required this.horasDictado,
    this.esAnual = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = horasNegocio + horasBlandas + horasLibres + horasDictado;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: equiposPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Distribución por categoría',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: equiposInk,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: esAnual
                    ? 'Suma de las horas válidas por categoría de los meses con datos del año.'
                    : 'Horas validadas del período que aplican al objetivo de cada integrante, agrupadas por categoría.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: equiposMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Leandro: llama a EquiposDonutChart para mostrar las horas por categoría.
          EquiposDonutChart(
            centerValue: total.toStringAsFixed(1),
            centerLabel: 'HORAS',
            valueSuffix: ' h',
            slices: [
              EquiposDonutSlice(
                label: 'Negocio',
                help:
                    'Horas de capacitaciones asociadas a habilidades de negocio y herramientas.',
                value: horasNegocio,
                color: equiposBrand,
              ),
              EquiposDonutSlice(
                label: 'Blandas',
                help:
                    'Horas de capacitaciones clasificadas como habilidades blandas.',
                value: horasBlandas,
                color: const Color(0xFF009B61),
              ),
              EquiposDonutSlice(
                label: 'Libres',
                help:
                    'Horas de formación libre o exploratoria realizadas por los integrantes.',
                value: horasLibres,
                color: const Color(0xFFDB2777),
              ),
              EquiposDonutSlice(
                label: 'Dictado',
                help:
                    'Horas cargadas como dictado de capacitaciones por integrantes del equipo.',
                value: horasDictado,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
