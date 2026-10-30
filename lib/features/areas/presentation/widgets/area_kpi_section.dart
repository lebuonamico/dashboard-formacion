import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:flutter/material.dart';

/// Indicadores de todas las áreas, con las mismas cards que el inicio.
class AreasKpiSection extends StatelessWidget {
  final int totalAreas;
  final int totalEmployees;
  final double completedHours;
  final double targetHours;
  final double hoursDeviation;
  final double complianceGlobal;
  final bool isAnnual;
  final int year;
  final int month;

  /// Variación del cumplimiento contra el mes anterior.
  final ComplianceVariation? variation;

  /// Proyección a fin de año de todas las áreas; sin ella no se muestra la
  /// card.
  final AnnualProjection? projection;

  const AreasKpiSection({
    super.key,
    required this.totalAreas,
    required this.totalEmployees,
    required this.completedHours,
    required this.targetHours,
    required this.hoursDeviation,
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
          percentage: complianceGlobal,
          variation: variation,
        ),
        if (projection case final projection?)
          projectionKpiCard(context, projection),
      ],
    );
  }
}

/// Horas válidas para el objetivo contra la meta del período, como en el
/// inicio.
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
    value: '${hours.toStringAsFixed(1)} h',
    suffix: 'para el objetivo',
    progress: target == 0 ? 0 : (hours / target).clamp(0.0, 1.0),
    progressLabel: 'Meta: ${target.toStringAsFixed(0)} h',
    footer: missing > 0
        ? '${missing.toStringAsFixed(1)} h para la meta'
        : 'Meta alcanzada',
    icon: Icons.schedule_outlined,
    color: context.colorScheme.primary,
    help: isAnnual ? annualCreditedHoursHelp : monthCreditedHoursHelp,
  );
}
