import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';
import 'package:flutter/material.dart';

class TeamsKpiSection extends StatelessWidget {
  final int teamCount;
  final int employeeCount;
  final double completedHours;
  final double targetHours;
  final double overallCompletion;
  final bool isAnnual;
  final int year;
  final int month;

  final ComplianceVariation? variation;

  final AnnualProjection? projection;

  const TeamsKpiSection({
    super.key,
    required this.teamCount,
    required this.employeeCount,
    required this.completedHours,
    required this.targetHours,
    required this.overallCompletion,
    required this.year,
    required this.month,
    this.isAnnual = false,
    this.variation,
    this.projection,
  });

  @override
  Widget build(BuildContext context) {
    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'EQUIPOS ACTIVOS',
          value: '$teamCount',
          suffix: 'en seguimiento',
          progress: 1,
          progressLabel: 'Con colaboradores elegibles',
          footer: '',
          icon: Icons.groups_outlined,
          color: context.colorScheme.primary,
          help:
              'Equipos con al menos un colaborador elegible en el período '
              'elegido.',
        ),
        DashboardKpiCard(
          title: 'COLABORADORES',
          value: '$employeeCount',
          suffix: 'en todos los equipos',
          progress: 1,
          progressLabel: 'Nómina elegible',
          footer: '',
          icon: Icons.people_outline,
          color: context.colors.cyanAccent,
          help: eligiblePayrollHelp,
        ),
        creditedHoursKpiCard(
          context,
          isAnnual: isAnnual,
          year: year,
          month: month,
          hours: completedHours,
          target: targetHours,
        ),
        complianceKpiCard(
          context,
          isAnnual: isAnnual,
          year: year,
          month: month,
          percentage: overallCompletion,
          variation: variation,
        ),
        if (projection case final projection?)
          projectionKpiCard(context, projection),
      ],
    );
  }
}
