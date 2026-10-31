import 'package:app_finnegans/core/widgets/status_colors.dart';
import 'package:app_finnegans/core/widgets/summary_card/status_badge.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card_footer.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card_header.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_info_row.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_progress.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/presentation/team_status_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TeamCard extends StatelessWidget {
  final TeamOverview team;
  final bool isAnnual;

  /// Text under the name; the area by default.
  final String? subtitle;

  /// Menu section the user came from, so the detail highlights it.
  final String origin;

  const TeamCard({
    super.key,
    required this.team,
    this.isAnnual = false,
    this.subtitle,
    this.origin = 'equipos',
  });

  @override
  Widget build(BuildContext context) {
    final colors = team.status.colors(context);

    return SummaryCard(
      colors: colors,
      onTap: () => context.push(
        '/areas/${Uri.encodeComponent(team.area)}/equipos/${Uri.encodeComponent(team.name)}?origen=$origin',
      ),
      header: SummaryCardHeader(
        title: team.name,
        subtitle: subtitle ?? team.area,
        badge: StatusBadge(label: team.status.label, colors: colors),
      ),
      details: [
        SummaryInfoRow(
          icon: Icons.person_outline,
          text: 'Líder: ${team.leader}',
        ),
      ],
      progress: SummaryProgress(
        caption: '${team.membersOnTarget} de ${team.memberCount} en objetivo',
        percentage: team.completionPercentage,
        colors: colors,
        help: isAnnual
            ? 'Colaboradores que tuvieron objetivo en este equipo durante al menos uno de los meses con datos del año.'
            : 'Personas que cumplen su plan por categoría. El porcentaje de la derecha compara horas realizadas contra objetivo.',
      ),
      footer: SummaryCardFooter(
        completedHours: team.completedHours,
        targetHours: team.targetHours,
        deviation: team.hoursDeviation,
        actionLabel: 'Ver detalle',
      ),
    );
  }
}
