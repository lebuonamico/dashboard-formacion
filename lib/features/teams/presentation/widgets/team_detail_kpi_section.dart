import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_kpi_section.dart';
import 'package:app_finnegans/features/teams/presentation/team_status_colors.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/projection/presentation/widgets/compliance_kpi_cards.dart';

class TeamDetailKpiSection extends ConsumerWidget {
  final TeamOverview team;
  final bool isAnnual;

  const TeamDetailKpiSection({
    super.key,
    required this.team,
    required this.isAnnual,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(periodFilterProvider).year;
    final month = ref.watch(periodFilterProvider).month;
    final projection = ref
        .watch(annualProjectionProvider((area: team.area, team: team.name)))
        .value;

    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'INTEGRANTES',
          value: '${team.memberCount}',
          suffix: team.memberCount == 1
              ? 'colaborador del equipo'
              : 'colaboradores del equipo',
          progress: team.memberCount == 0
              ? 0
              : team.membersOnTarget / team.memberCount,
          progressLabel:
              '${team.membersOnTarget} de ${team.memberCount} en objetivo',
          footer: '',
          icon: Icons.people_outline,
          color: context.colorScheme.primary,
          help: membersHelp('del equipo'),
        ),
        creditedHoursKpiCard(
          context,
          isAnnual: isAnnual,
          year: year,
          month: month,
          hours: team.completedHours,
          target: team.targetHours,
        ),
        DashboardKpiCard(
          title: 'OBJETIVO DEL PERÍODO',
          value: '${formatHours(team.targetHours)} hs',
          suffix: 'según seniority',
          progress: 1,
          progressLabel: isAnnual
              ? 'Suma de los objetivos del año'
              : 'Objetivo del mes',
          footer: '',
          icon: Icons.flag_outlined,
          color: context.colors.violetAccent,
          help: targetHelp('el equipo'),
        ),

        ComplianceKpiCard(
          isAnnual: isAnnual,
          year: year,
          month: month,
          percentage: team.completionPercentage,
          variation: ref
              .watch(
                complianceVariationProvider((area: team.area, team: team.name)),
              )
              .value,
          color: team.status.colors(context).text,
        ),
        if (projection != null) ProjectionKpiCard(projection: projection),
      ],
    );
  }
}
