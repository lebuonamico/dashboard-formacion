import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_donut_chart.dart';
import 'package:flutter/material.dart';

class AreasStatusSummary extends StatelessWidget {
  final int total;
  final int enObjetivo;
  final int enRiesgo;
  final int criticos;

  const AreasStatusSummary({
    super.key,
    required this.total,
    required this.enObjetivo,
    required this.enRiesgo,
    required this.criticos,
  });

  @override
  Widget build(BuildContext context) {
    final requierenAtencion = enRiesgo + criticos;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.panel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: _StatusHeading(requierenAtencion: requierenAtencion),
          ),
          const SizedBox(height: 12),
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 166),
              child: Center(
                child: AreasDonutChart(
                  centerValue: '$total',
                  centerLabel: 'ÁREAS',
                  slices: [
                    AreasDonutSlice(
                      label: 'En objetivo',
                      value: enObjetivo.toDouble(),
                      color: context.colores.exito.texto,
                      backgroundColor: context.colores.exito.fondo,
                      help:
                          'Áreas con 100% o más de las horas objetivo del período.',
                    ),
                    AreasDonutSlice(
                      label: 'En riesgo',
                      value: enRiesgo.toDouble(),
                      color: context.colores.advertencia.texto,
                      backgroundColor: context.colores.advertencia.fondo,
                      help:
                          'Áreas con al menos 70% de las horas objetivo, pero sin llegar al 100%.',
                    ),
                    AreasDonutSlice(
                      label: 'Críticas',
                      value: criticos.toDouble(),
                      color: context.colores.peligro.texto,
                      backgroundColor: context.colores.peligro.fondo,
                      help:
                          'Áreas por debajo del 70% de las horas objetivo del período.',
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

class _StatusHeading extends StatelessWidget {
  final int requierenAtencion;

  const _StatusHeading({required this.requierenAtencion});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Estado de las áreas',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'El estado del área sólo mira el porcentaje de horas: 100% o más está en objetivo, desde 70% en riesgo y debajo de 70% es crítico.',
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
        const SizedBox(height: 5),
        Text(
          requierenAtencion == 0
              ? 'No hay áreas que requieran atención.'
              : '$requierenAtencion ${requierenAtencion == 1 ? 'área requiere' : 'áreas requieren'} atención.',
          style: TextStyle(
            fontSize: 13,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
