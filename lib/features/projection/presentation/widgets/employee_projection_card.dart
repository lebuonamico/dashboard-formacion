import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/projection/domain/projection_service.dart';
import 'package:app_finnegans/core/period/period_formatter.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/widgets/status_colors.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:flutter/material.dart';

/// Proyección a fin de año de un colaborador: si llega con su tendencia y,
/// si no, cuántas horas le faltan en cada habilidad de su plan.
class EmployeeProjectionCard extends StatelessWidget {
  final EmployeeProjection projection;
  final int year;

  const EmployeeProjectionCard({
    super.key,
    required this.projection,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = projection.status.colors(context);
    final closed = projection.remainingMonths == 0;
    final missing = projection.missing;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formatPercentage(projection.percentage),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (projection.variation case final variation?) ...[
                const SizedBox(width: 8),
                variationBadge(context, variation, 'pts'),
              ],
              const Spacer(),
              Container(
                key: const Key('proyeccion_empleado_estado'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  projection.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${projection.projection.toStringAsFixed(0)} / '
            '${projection.goal.toStringAsFixed(0)} h proyectadas a diciembre',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Corte: ${monthName(projection.cutoffMonth)} $year · tendencia de sus '
            'horas en los meses con datos',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (missing.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: context.colors.success.text,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    closed
                        ? 'Cumplió todas las habilidades de su plan.'
                        : 'Con su tendencia cumple todas las habilidades de su plan.',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              closed
                  ? 'No llegó a cumplir:'
                  : 'Para llegar a diciembre tiene que reforzar:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            for (final category in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: context.colors.danger.text,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${category.type.label} · '
                        '${closed ? 'faltaron' : 'faltan'} '
                        '${category.missing.toStringAsFixed(1)} h'
                        '${closed ? '' : ' (+${(category.missing / projection.remainingMonths).toStringAsFixed(1)} h/mes)'}',
                        key: Key('proyeccion_falta_${category.type.name}'),
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              for (final category in projection.categories)
                Text(
                  '${category.type.label}: '
                  '${category.accumulated.toStringAsFixed(1)} / '
                  '${category.goal.toStringAsFixed(0)} h · proyecta '
                  '${category.projected.toStringAsFixed(1)} h '
                  '${category.arrives ? '✓' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: category.arrives
                        ? context.colors.success.text
                        : cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
