import 'package:app_finnegans/features/compliance/presentation/compliance_level_colors.dart';
import 'package:app_finnegans/core/widgets/summary_card/status_badge.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card_footer.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card_header.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_info_row.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_progress.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AreaCard extends StatelessWidget {
  final AreaSummary area;
  final bool isAnnual;

  /// Menu section the user came from, so the detail highlights it.
  final String? origin;

  const AreaCard({
    super.key,
    required this.area,
    this.isAnnual = false,
    this.origin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = area.level.colors(context);
    final destination = '/areas/${Uri.encodeComponent(area.name)}';
    final employees = area.memberCount;
    final leaders = area.leaders;

    return SummaryCard(
      colors: colors,
      onTap: () => context.push(
        origin == null ? destination : '$destination?origen=$origin',
      ),
      header: SummaryCardHeader(
        title: area.name,
        subtitle:
            '$employees ${employees == 1 ? 'colaborador' : 'colaboradores'}',
        badge: StatusBadge(label: area.level.label, colors: colors),
      ),
      details: [
        SummaryInfoRow(
          icon: Icons.groups_outlined,
          text: area.generalTeams.isEmpty
              ? 'Sin equipo general asignado'
              : 'Equipos: ${area.generalTeams.join(', ')}',
          withTooltip: true,
        ),
        if (leaders != null) ...[
          const SizedBox(height: 6),
          SummaryInfoRow(
            icon: Icons.person_outline,
            text: 'Líder de área: $leaders',
            withTooltip: true,
          ),
        ],
      ],
      progress: SummaryProgress(
        caption: '${area.membersOnTarget} de ${area.memberCount} en objetivo',
        percentage: area.compliancePercentage,
        colors: colors,
        help: isAnnual
            ? 'Colaboradores que tuvieron objetivo en esta área durante al menos uno de los meses con datos del año.'
            : 'Personas que cumplen su plan por categoría. El porcentaje de la derecha compara horas realizadas contra objetivo.',
      ),
      footer: SummaryCardFooter(
        completedHours: area.completedHours,
        targetHours: area.targetHours,
        deviation: area.hoursDeviation,
        actionLabel: 'Ver área',
      ),
    );
  }
}
