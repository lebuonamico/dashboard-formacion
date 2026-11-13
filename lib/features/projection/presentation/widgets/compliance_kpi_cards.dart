import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_colors.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';
import 'package:app_finnegans/features/projection/presentation/projection_labels.dart';
import 'package:app_finnegans/features/projection/presentation/projection_status_colors.dart';
import 'package:flutter/material.dart';

/// Annual: the year-to-date compliance and its change in points against the
/// previous month. Monthly: the month's compliance and the change in hours
/// per employee. [color] replaces the traffic-light color when the section has
/// its own status.
class ComplianceKpiCard extends StatelessWidget {
  final bool isAnnual;
  final int year;
  final int month;
  final double percentage;
  final ComplianceVariation? variation;
  final Color? color;

  const ComplianceKpiCard({
    super.key,
    required this.isAnnual,
    required this.year,
    required this.month,
    required this.percentage,
    this.variation,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final variation = this.variation;
    final colorCard =
        color ??
        const ComplianceLevelService()
            .fromPercentage(percentage)
            .colors(context)
            .text;
    if (isAnnual) {
      final points = variation?.points;
      return DashboardKpiCard(
        title: 'CUMPLIMIENTO · AÑO $year',
        value: formatPercentage(percentage),
        suffix: 'acumulado del año',
        suffixBelow: true,
        progress: (percentage / 100).clamp(0.0, 1.0),
        progressLabel: 'Acumulado del año',
        footer: '',
        badge: points == null
            ? null
            : VariationBadge(
                key: const Key('kpi_variacion_mes'),
                value: points,
                unit: 'pts',
              ),
        icon: Icons.event_available_outlined,
        color: colorCard,
        help:
            'Horas válidas acumuladas en el año sobre la suma de los objetivos '
            'de los meses con datos. Los meses sin registros CRM ni LMS no '
            'cuentan. El recuadro muestra cuántos puntos cambió contra el '
            'acumulado hasta el mes anterior.',
      );
    }

    final previous = variation?.previousHoursPerPerson;
    // The badge keeps one decimal, so the two figures it compares show one
    // too, and it is their difference as shown: 4,2 and 4,4 read -0,2, not
    // the -0,1 of the unrounded 4.24 and 4.35. Same tenths as
    // `formatHoursPrecise`.
    int tenths(double hours) => (hours * 10).round();
    final shownChange = variation == null || previous == null
        ? null
        : (tenths(variation.hoursPerPerson) - tenths(previous)) / 10;
    return DashboardKpiCard(
      title: 'CUMPLIMIENTO · ${monthName(month).toUpperCase()} $year',
      value: formatPercentage(percentage),
      suffix: 'del objetivo del mes',
      progress: (percentage / 100).clamp(0.0, 1.0),
      progressLabel: variation == null
          ? ''
          : '${formatHoursPrecise(variation.hoursPerPerson)} hs por colaborador',
      footer: previous == null
          ? 'Sin datos del mes anterior'
          : 'Mes anterior: ${formatHoursPrecise(previous)} hs',
      badge: shownChange == null
          ? null
          : VariationBadge(
              key: const Key('kpi_variacion_mes'),
              value: shownChange,
              unit: 'hs',
            ),
      icon: Icons.event_available_outlined,
      color: colorCard,
      help:
          'Horas válidas del mes sobre el objetivo del mes de los colaboradores '
          'elegibles, según su seniority. Cada colaborador suma como máximo su '
          'objetivo en cada categoría. El recuadro compara las horas por '
          'colaborador con el mes anterior.',
    );
  }
}

class ProjectionKpiCard extends StatelessWidget {
  final AnnualProjection projection;

  const ProjectionKpiCard({super.key, required this.projection});

  @override
  Widget build(BuildContext context) {
    final colors = projection.status.colors(context);
    final goal = projection.goal;
    final closed = projection.remainingMonths == 0;
    final variation = projection.projectionVariation;

    return DashboardKpiCard(
      title: 'PROYECCIÓN ANUAL',
      value: formatPercentage(projection.percentage),
      suffix:
          '${formatAchievedHours(projection.projection, target: goal)} / '
          '${formatHours(goal)} hs por colaborador',
      suffixBelow: true,
      progress: goal == 0 ? 1 : (projection.projection / goal).clamp(0.0, 1.0),
      progressLabel:
          '${projection.status.label} · ${projection.arrive} de '
          '${projection.employeeCount} ${closed ? 'cumplieron' : 'llegan'}',
      footer: closed
          ? 'Año cerrado: ${formatPercentage(projection.percentage)} del objetivo'
          : projection.adjustment > 0
          ? 'Ajuste: +${formatMissingHours(projection.adjustment)} hs/mes por colaborador'
          : 'En camino al objetivo',
      badge: variation == null
          ? null
          : VariationBadge(
              key: const Key('kpi_variacion_proyeccion'),
              value: variation,
              unit: 'pts',
            ),
      icon: switch (projection.status) {
        ProjectionStatus.onTrack => Icons.trending_up,
        ProjectionStatus.reachable => Icons.trending_flat,
        ProjectionStatus.atRisk => Icons.trending_down,
      },
      color: colors.text,
      help:
          'Estimación a diciembre: lo acumulado más la tendencia de cada '
          'colaborador según sus meses con datos, sobre el objetivo del año. Las '
          'horas de un colaborador no cubren a otro, ni las de una categoría a '
          'otra. En camino: 100% o más; Alcanzable: desde 85%; En riesgo: '
          'menos de 85%. El ajuste son las horas por colaborador y por mes que '
          'faltan para llegar.',
    );
  }
}
