import 'package:app_finnegans/presentation/widgets/areas/area_donut_chart.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:flutter/material.dart';

class AreasCategoryDistribution extends StatelessWidget {
  final double horasNegocio;
  final double horasBlandas;
  final double horasLibres;
  final double horasDictado;
  final bool esAnual;

  const AreasCategoryDistribution({
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
      decoration: areasPanelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                children: [
                  const Text(
                    'Distribución por categoría',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: areasInk,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: esAnual
                        ? 'Suma de las horas válidas por categoría de los meses con datos del año.'
                        : 'Horas validadas del período que aplican al objetivo de cada colaborador, agrupadas por categoría.',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: areasMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 166),
              child: Center(
                child: AreasDonutChart(
                  centerValue: total.toStringAsFixed(1),
                  centerLabel: 'HORAS',
                  valueSuffix: ' h',
                  slices: [
                    AreasDonutSlice(
                      label: 'Negocio',
                      help:
                          'Horas de capacitaciones asociadas a habilidades de negocio y herramientas.',
                      value: horasNegocio,
                      color: areasBrand,
                    ),
                    AreasDonutSlice(
                      label: 'Blandas',
                      help:
                          'Horas de capacitaciones clasificadas como habilidades blandas.',
                      value: horasBlandas,
                      color: const Color(0xFF009B61),
                    ),
                    AreasDonutSlice(
                      label: 'Libres',
                      help:
                          'Horas de formación libre o exploratoria realizadas por los colaboradores de las áreas.',
                      value: horasLibres,
                      color: const Color(0xFFDB2777),
                    ),
                    AreasDonutSlice(
                      label: 'Dictado',
                      help:
                          'Horas cargadas como dictado de capacitaciones por colaboradores de las áreas.',
                      value: horasDictado,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
