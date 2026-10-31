import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/status_colors.dart';
import 'package:go_router/go_router.dart';

/// Grilla de los equipos generales de un área, con título y conteo.
class AreaTeamsGrid extends StatelessWidget {
  final List<TeamOverview> teams;
  final bool isAnnual;
  final String origin;

  const AreaTeamsGrid({
    super.key,
    required this.teams,
    required this.origin,
    this.isAnnual = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Equipos del área',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: teams.length),
          ],
        ),
        const SizedBox(height: 13),
        if (teams.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: context.panel(),
            child: Text(
              'No hay equipos generales asignados.',
              style: TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 410,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 252,
            ),
            itemCount: teams.length,
            itemBuilder: (context, index) => AreaTeamCard(
              team: teams[index],
              isAnnual: isAnnual,
              origin: origin,
            ),
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Tarjeta de un equipo dentro del detalle de área, con el estilo de la
/// pantalla de Equipos.
class AreaTeamCard extends StatelessWidget {
  final TeamOverview team;
  final bool isAnnual;

  /// Sección del menú desde la que se llegó, para que el detalle la resalte.
  final String origin;

  const AreaTeamCard({
    super.key,
    required this.team,
    required this.origin,
    this.isAnnual = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (team.completionPercentage / 100).clamp(0.0, 1.0);
    final statusColor = team.status.colors(context).text;

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(
          '/areas/${Uri.encodeComponent(team.area)}/equipos/${Uri.encodeComponent(team.name)}?origen=$origin',
        ),
        child: Container(
          decoration: context.panel(shadow: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor,
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
    final members = team.memberCount;

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
              // El área ya es el título de la pantalla: acá va la nómina.
              Text(
                '$members ${members == 1 ? 'integrante' : 'integrantes'}',
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
    final statusColor = team.status.colors(context).text;

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
                color: statusColor,
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
            color: statusColor,
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
                _formatDeviation(team.hoursDeviation),
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

  String _formatDeviation(double hoursDeviation) {
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
    final ColorPair(text: text, background: background) = status.colors(
      context,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: context.textTheme.labelMedium?.copyWith(
              color: text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
