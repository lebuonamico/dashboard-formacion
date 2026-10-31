import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/widgets/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/teams/presentation/team_status_labels.dart';

class TeamCard extends StatelessWidget {
  final TeamOverview team;
  final bool isAnnual;

  const TeamCard({super.key, required this.team, this.isAnnual = false});

  @override
  Widget build(BuildContext context) {
    final progress = (team.completionPercentage / 100).clamp(0.0, 1.0);

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),

        onTap: () => context.push(
          '/areas/${Uri.encodeComponent(team.area)}/equipos/${Uri.encodeComponent(team.name)}?origen=equipos',
        ),
        child: Container(
          decoration: context.panel(shadow: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: team.status.colors(context).text,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardHeader(team: team),
                      const SizedBox(height: 13),
                      _LeaderRow(leader: team.leader),
                      const Spacer(),

                      _ProgressSection(
                        team: team,
                        progress: progress,
                        isAnnual: isAnnual,
                      ),
                      const SizedBox(height: 9),
                      _CardFooter(team: team),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final TeamOverview team;

  const _CardHeader({required this.team});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge?.copyWith(
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                team.area,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusBadge(status: team.status),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final String leader;

  const _LeaderRow({required this.leader});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.person_outline,
          size: 16,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Líder: $leader',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final TeamOverview team;
  final double progress;
  final bool isAnnual;

  const _ProgressSection({
    required this.team,
    required this.progress,
    required this.isAnnual,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${team.membersOnTarget} de ${team.memberCount} en objetivo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Tooltip(
                    message: isAnnual
                        ? 'Colaboradores que tuvieron objetivo en este equipo durante al menos uno de los meses con datos del año.'
                        : 'Personas que cumplen su plan por categoría. El porcentaje de la derecha compara horas realizadas contra objetivo.',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPercentage(team.completionPercentage),
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: team.status.colors(context).text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: context.colors.chartTrack,
            color: team.status.colors(context).text,
          ),
        ),
      ],
    );
  }
}

class _CardFooter extends StatelessWidget {
  final TeamOverview team;

  const _CardFooter({required this.team});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '${team.completedHours.toStringAsFixed(1)} de ${team.targetHours.toStringAsFixed(1)} hs',
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatHoursDeviation(team.hoursDeviation),
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: team.hoursDeviation >= 0
                      ? context.colors.success.text
                      : context.colors.danger.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Ver detalle',
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.arrow_forward_rounded,
          size: 15,
          color: context.colorScheme.primary,
        ),
      ],
    );
  }

  String _formatHoursDeviation(double hoursDeviation) {
    if (hoursDeviation >= 0) {
      return '+${hoursDeviation.toStringAsFixed(1)} hs';
    }

    return '-${hoursDeviation.abs().toStringAsFixed(1)} hs';
  }
}

class _StatusBadge extends StatelessWidget {
  final TeamStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.colors(context).background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.colors(context).text,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: context.textTheme.labelMedium?.copyWith(
              color: status.colors(context).text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
