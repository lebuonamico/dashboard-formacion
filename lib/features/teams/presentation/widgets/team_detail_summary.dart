import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/widgets/status_colors.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_category_distribution.dart';
import 'package:flutter/material.dart';

class TeamDetailHeader extends StatelessWidget {
  final TeamOverview team;
  final String periodLabel;

  const TeamDetailHeader({
    super.key,
    required this.team,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
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
              team.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${team.area} · Líder: ${team.leader}',
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
                    periodLabel,
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
                color: team.status.colors(context).background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                team.status.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: team.status.colors(context).text,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TeamDetailSummary extends StatelessWidget {
  static const _horizontalPanelsBreakpoint = 1050.0;
  final TeamOverview team;
  final bool isAnnual;

  const TeamDetailSummary({
    super.key,
    required this.team,
    this.isAnnual = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final distribution = TeamCategoryDistribution(
          businessHours: team.businessHours,
          softSkillsHours: team.softSkillsHours,
          explorationHours: team.explorationHours,
          teachingHours: team.teachingHours,
          isAnnual: isAnnual,
        );

        final progressPanel = _TeamProgressPanel(
          team: team,
          isAnnual: isAnnual,
        );

        if (constraints.maxWidth < _horizontalPanelsBreakpoint) {
          return Column(
            children: [distribution, const SizedBox(height: 16), progressPanel],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: distribution),
              const SizedBox(width: 16),
              Expanded(child: progressPanel),
            ],
          ),
        );
      },
    );
  }
}

class _TeamProgressPanel extends StatelessWidget {
  final TeamOverview team;
  final bool isAnnual;

  const _TeamProgressPanel({required this.team, required this.isAnnual});

  @override
  Widget build(BuildContext context) {
    final progress = (team.completionPercentage / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avance del equipo',
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
                formatPercentage(team.completionPercentage),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: team.status.colors(context).text,
                ),
              ),
              Text(
                '${team.completedHours.toStringAsFixed(1)} de ${team.targetHours.toStringAsFixed(1)} h',
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
              color: team.status.colors(context).text,
            ),
          ),
          const SizedBox(height: 20),
          if (isAnnual)
            Tooltip(
              message:
                  'Colaboradores que tuvieron objetivo en este equipo durante al menos uno de los meses con datos del año.',
              child: _MetricRow(
                label: 'Integrantes en objetivo',
                value: '${team.membersOnTarget} de ${team.memberCount}',
              ),
            )
          else
            _MetricRow(
              label: 'Integrantes en objetivo',
              value: '${team.membersOnTarget} de ${team.memberCount}',
            ),
          const Divider(height: 22),
          _MetricRow(
            label: 'Promedio por integrante',
            value: '${team.averageHoursPerMember.toStringAsFixed(1)} h',
          ),
          const Divider(height: 22),
          _MetricRow(
            label: 'Desvío de horas',
            value: team.hoursDeviation >= 0
                ? '+${team.hoursDeviation.toStringAsFixed(1)} h'
                : '-${team.hoursDeviation.abs().toStringAsFixed(1)} h',
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
