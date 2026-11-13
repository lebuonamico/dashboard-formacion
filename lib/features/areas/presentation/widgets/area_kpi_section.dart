import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';
import 'package:app_finnegans/features/projection/presentation/widgets/compliance_kpi_cards.dart';

/// Indicators of every area, with the same cards as the home screen.
class AreasKpiSection extends StatelessWidget {
  final int totalAreas;
  final int totalEmployees;
  final double completedHours;
  final double targetHours;
  final double complianceGlobal;
  final bool isAnnual;
  final int year;
  final int month;

  final ComplianceVariation? variation;

  /// Year-end projection of every area; without it the card is hidden.
  final AnnualProjection? projection;

  const AreasKpiSection({
    super.key,
    required this.totalAreas,
    required this.totalEmployees,
    required this.completedHours,
    required this.targetHours,
    required this.complianceGlobal,
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
          title: 'ÁREAS ACTIVAS',
          value: '$totalAreas',
          suffix: 'en seguimiento',
          progress: 1,
          progressLabel: 'Con colaboradores elegibles',
          footer: '',
          icon: Icons.apartment_outlined,
          color: context.colorScheme.primary,
          help:
              'Áreas con al menos un colaborador elegible en el período '
              'elegido.',
        ),
        DashboardKpiCard(
          title: 'COLABORADORES',
          value: '$totalEmployees',
          suffix: 'en todas las áreas',
          progress: 1,
          progressLabel: 'Colaboradores elegibles',
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
        ComplianceKpiCard(
          isAnnual: isAnnual,
          year: year,
          month: month,
          percentage: complianceGlobal,
          variation: variation,
        ),
        if (projection case final projection?)
          ProjectionKpiCard(projection: projection),
      ],
    );
  }
}

/// Credited hours against the period's target, as on the home screen.
Widget creditedHoursKpiCard(
  BuildContext context, {
  required bool isAnnual,
  required int year,
  required int month,
  required double hours,
  required double target,
}) {
  final period = isAnnual
      ? 'AÑO $year'
      : '${monthName(month).toUpperCase()} $year';
  final missing = target - hours;
  return DashboardKpiCard(
    title: 'HORAS VÁLIDAS · $period',
    value: '${formatAchievedHours(hours, target: target)} hs',
    suffix: isAnnual ? 'en el año' : 'en el mes',
    progress: target == 0 ? 0 : (hours / target).clamp(0.0, 1.0),
    progressLabel: 'Objetivo: ${formatHours(target)} hs',
    footer: missing > 0
        ? '${formatMissingHours(missing)} hs para el objetivo'
        : 'Objetivo alcanzado',
    icon: Icons.schedule_outlined,
    color: context.colorScheme.primary,
    help: isAnnual ? annualCreditedHoursHelp : monthCreditedHoursHelp,
  );
}
