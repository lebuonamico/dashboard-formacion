import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_donut_chart.dart';
import 'package:flutter/material.dart';

class AreasStatusSummary extends StatelessWidget {
  final int total;
  final int onTarget;
  final int atRisk;
  final int critical;

  const AreasStatusSummary({
    super.key,
    required this.total,
    required this.onTarget,
    required this.atRisk,
    required this.critical,
  });

  @override
  Widget build(BuildContext context) {
    final needAttention = atRisk + critical;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.panel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: _StatusHeading(needAttention: needAttention),
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
                      value: onTarget.toDouble(),
                      color: context.colors.success.text,
                      backgroundColor: context.colors.success.background,
                      help:
                          'Áreas con 100% o más de las horas objetivo del período.',
                    ),
                    AreasDonutSlice(
                      label: 'En riesgo',
                      value: atRisk.toDouble(),
                      color: context.colors.warning.text,
                      backgroundColor: context.colors.warning.background,
                      help:
                          'Áreas con al menos 70% de las horas objetivo, pero sin llegar al 100%.',
                    ),
                    AreasDonutSlice(
                      label: 'Críticas',
                      value: critical.toDouble(),
                      color: context.colors.danger.text,
                      backgroundColor: context.colors.danger.background,
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
  final int needAttention;

  const _StatusHeading({required this.needAttention});

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
          needAttention == 0
              ? 'No hay áreas que requieran atención.'
              : '$needAttention ${needAttention == 1 ? 'área requiere' : 'áreas requieren'} atención.',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
