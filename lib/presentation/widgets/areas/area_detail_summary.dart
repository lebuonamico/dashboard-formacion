import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_category_distribution.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';

class AreaDetailHeader extends StatelessWidget {
  final AreaGlobalViewModel area;
  final String period;

  const AreaDetailHeader({super.key, required this.area, required this.period});

  @override
  Widget build(BuildContext context) {
    final employees = area.memberCount;
    final teams = area.generalTeams.length;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              area.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$employees ${employees == 1 ? 'colaborador' : 'colaboradores'}'
              ' · $teams ${teams == 1 ? 'equipo general' : 'equipos generales'}'
              '${area.leaders == null ? '' : ' · Líder de área: ${area.leaders}'}',
              style: TextStyle(
                fontSize: 14,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                border: Border.all(color: context.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    period,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: area.level.colors(context).background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                area.level.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: area.level.colors(context).text,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AreaDetailSummary extends StatelessWidget {
  final AreaGlobalViewModel area;
  final bool isAnnual;

  const AreaDetailSummary({
    super.key,
    required this.area,
    this.isAnnual = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final distribution = AreasCategoryDistribution(
          businessHours: area.businessHours,
          softSkillsHours: area.softSkillsHours,
          explorationHours: area.explorationHours,
          teachingHours: area.teachingHours,
          isAnnual: isAnnual,
        );
        final progress = _AreaProgressPanel(area: area, isAnnual: isAnnual);

        if (constraints.maxWidth < 1050) {
          return Column(
            children: [distribution, const SizedBox(height: 16), progress],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: distribution),
              const SizedBox(width: 16),
              Expanded(child: progress),
            ],
          ),
        );
      },
    );
  }
}

class _AreaProgressPanel extends StatelessWidget {
  final AreaGlobalViewModel area;
  final bool isAnnual;

  const _AreaProgressPanel({required this.area, required this.isAnnual});

  @override
  Widget build(BuildContext context) {
    final progress = (area.compliancePercentage / 100).clamp(0.0, 1.0);
    final average = area.memberCount == 0
        ? 0.0
        : area.completedHours / area.memberCount;
    final onTarget = _MetricRow(
      label: 'Integrantes en objetivo',
      value: '${area.membersOnTarget} de ${area.memberCount}',
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avance del área',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatPercentage(area.compliancePercentage),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: area.level.colors(context).text,
                ),
              ),
              Text(
                '${area.completedHours.toStringAsFixed(1)} de ${area.targetHours.toStringAsFixed(1)} h',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: context.colors.chartTrack,
              color: area.level.colors(context).text,
            ),
          ),
          const SizedBox(height: 20),
          if (isAnnual)
            Tooltip(
              message:
                  'Colaboradores que tuvieron objetivo en esta área durante al menos uno de los meses con datos del año.',
              child: onTarget,
            )
          else
            onTarget,
          const Divider(height: 22),
          _MetricRow(
            label: 'Promedio por integrante',
            value: '${average.toStringAsFixed(1)} h',
          ),
          const Divider(height: 22),
          _MetricRow(
            label: 'Desvío de horas',
            value: area.hoursDeviation >= 0
                ? '+${area.hoursDeviation.toStringAsFixed(1)} h'
                : '-${area.hoursDeviation.abs().toStringAsFixed(1)} h',
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
