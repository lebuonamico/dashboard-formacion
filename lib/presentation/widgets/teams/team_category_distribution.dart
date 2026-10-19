import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_donut_chart.dart';
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
      decoration: context.panel(),
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
                  Text(
                    'Distribución por categoría',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
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
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Leandro: llama a EquiposDonutChart para mostrar las horas por categoría.
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 166),
              child: Center(
                child: EquiposDonutChart(
                  centerValue: total.toStringAsFixed(1),
                  centerLabel: 'HORAS',
                  valueSuffix: ' h',
                  slices: [
                    EquiposDonutSlice(
                      label: 'Negocio',
                      help:
                          'Horas de capacitaciones asociadas a habilidades de negocio y herramientas.',
                      value: horasNegocio,
                      color: context.colores.negocio.texto,
                    ),
                    EquiposDonutSlice(
                      label: 'Blandas',
                      help:
                          'Horas de capacitaciones clasificadas como habilidades blandas.',
                      value: horasBlandas,
                      color: context.colores.blandas.texto,
                    ),
                    EquiposDonutSlice(
                      label: 'Libres',
                      help:
                          'Horas de formación libre o exploratoria realizadas por los integrantes.',
                      value: horasLibres,
                      color: context.colores.exploracion.texto,
                    ),
                    EquiposDonutSlice(
                      label: 'Dictado',
                      help:
                          'Horas cargadas como dictado de capacitaciones por integrantes del equipo.',
                      value: horasDictado,
                      color: context.colores.dictado.texto,
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
