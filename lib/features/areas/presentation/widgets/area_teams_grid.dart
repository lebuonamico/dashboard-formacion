import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/summary_card/count_badge.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_card.dart';
import 'package:flutter/material.dart';

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
            CountBadge(count: teams.length),
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
            itemBuilder: (context, index) {
              final team = teams[index];
              return TeamCard(
                team: team,
                isAnnual: isAnnual,
                origin: origin,
                subtitle:
                    '${team.memberCount} ${team.memberCount == 1 ? 'integrante' : 'integrantes'}',
              );
            },
          ),
      ],
    );
  }
}
