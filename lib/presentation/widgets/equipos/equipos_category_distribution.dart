import 'package:app_finnegans/presentation/widgets/equipos/equipos_donut_chart.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Muestra cómo se reparten las horas realizadas entre las categorías.
/// Leandro: Recibe totales ya calculados por la pantalla; este widget sólo presenta.
class EquiposCategoryDistribution extends StatelessWidget {
  final double horasNegocio;
  final double horasBlandas;
  final double horasLibres;
  final double horasDictado;

  const EquiposCategoryDistribution({
    super.key,
    required this.horasNegocio,
    required this.horasBlandas,
    required this.horasLibres,
    required this.horasDictado,
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
                message:
                    'Horas realizadas del período, agrupadas por tipo de capacitación.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: equiposMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                color: const Color(0xFF4F46E5),
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
