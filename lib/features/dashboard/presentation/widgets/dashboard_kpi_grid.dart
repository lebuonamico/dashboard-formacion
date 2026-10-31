import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';
import 'package:app_finnegans/features/projection/presentation/widgets/compliance_kpi_cards.dart';

export 'package:app_finnegans/core/widgets/kpi_card.dart';

class DashboardKpiGrid extends StatelessWidget {
  final AsyncValue<DashboardKpiSummary?> kpisAsync;
  final PeriodScope scope;
  final int selectedMonth;
  final int selectedYear;

  /// Year-end projection of the whole visible payroll.
  final AsyncValue<AnnualProjection?> projectionAsync;

  /// Compliance variation of the whole payroll against the previous month.
  final AsyncValue<ComplianceVariation?> variationAsync;

  const DashboardKpiGrid({
    super.key,
    required this.kpisAsync,
    required this.scope,
    required this.selectedMonth,
    required this.selectedYear,
    this.projectionAsync = const AsyncData(null),
    this.variationAsync = const AsyncData(null),
  });

  @override
  Widget build(BuildContext context) {
    return kpisAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorDataState(
        title: 'No pudimos cargar esta sección',
        error: error,
        compact: true,
      ),
      data: (summary) => summary == null
          ? const EmptyDataState(
              compact: true,
              icon: Icons.groups_outlined,
              title: 'No hay colaboradores elegibles en este período.',
              message: 'Verificá la nómina elegible del período.',
            )
          : _KpiCards(
              summary: summary,
              scope: scope,
              selectedMonth: selectedMonth,
              selectedYear: selectedYear,
              projection: projectionAsync.value,
              variation: variationAsync.value,
            ),
    );
  }
}

class _KpiCards extends StatelessWidget {
  final DashboardKpiSummary summary;
  final PeriodScope scope;
  final int selectedMonth;
  final int selectedYear;

  /// While loading, or if the year has no data, its card is hidden.
  final AnnualProjection? projection;
  final ComplianceVariation? variation;

  const _KpiCards({
    required this.summary,
    required this.scope,
    required this.selectedMonth,
    required this.selectedYear,
    required this.projection,
    required this.variation,
  });

  @override
  Widget build(BuildContext context) {
    final kpis = summary.kpis;
    final totalEmployees = kpis.employees;
    final completedHours = kpis.creditedHours;
    final employeesWhoTookCourse = kpis.training;
    final periodGoal = kpis.targetHours;
    final projection = this.projection;
    final isAnnual = scope == PeriodScope.annual;
    final periodLabel = isAnnual
        ? 'AÑO $selectedYear'
        : '${monthName(selectedMonth).toUpperCase()} $selectedYear';

    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'COLABORADORES',
          value: '$totalEmployees',
          suffix: ' nómina activa',
          progress: 1,
          progressLabel: '${summary.areaCount} áreas',
          footer: '${summary.teamCount} equipos',
          icon: Icons.groups_outlined,
          color: context.colorScheme.primary,
          help: '$eligiblePayrollHelp Abajo, cuántas áreas y equipos abarcan.',
        ),
        DashboardKpiCard(
          title: 'COLABORADORES CAPACITÁNDOSE',
          value: '$employeesWhoTookCourse',
          suffix: ' de $totalEmployees',
          progress: (employeesWhoTookCourse / totalEmployees).clamp(0.0, 1.0),
          progressLabel:
              '${(employeesWhoTookCourse / totalEmployees * 100).toStringAsFixed(0)}% de la nómina',
          footer:
              '${totalEmployees - employeesWhoTookCourse} sin cursos tomados',
          icon: Icons.school_outlined,
          color: context.colors.success.text,
          help:
              'Colaboradores elegibles con al menos una carga de horas en el '
              'CRM en el período, sin contar las horas que dictaron. No indica '
              'si cumplieron el objetivo.',
        ),
        // Only the hours that count towards the period's compliance target.
        DashboardKpiCard(
          title: 'HORAS VÁLIDAS · $periodLabel',
          value: '${completedHours.toStringAsFixed(1)} h',
          suffix: 'para el objetivo',
          progress: periodGoal == 0
              ? 0
              : (completedHours / periodGoal).clamp(0.0, 1.0),
          progressLabel: 'Meta: ${periodGoal.toStringAsFixed(0)} h',
          footer:
              '${(periodGoal - completedHours).clamp(0, double.infinity).toStringAsFixed(1)} h para la meta',
          icon: Icons.schedule_outlined,
          color: context.colorScheme.primary,
          help: isAnnual ? annualCreditedHoursHelp : monthCreditedHoursHelp,
        ),
        ComplianceKpiCard(
          isAnnual: isAnnual,
          year: selectedYear,
          month: selectedMonth,
          percentage: kpis.compliance,
          variation: variation,
        ),
        if (projection != null) ProjectionKpiCard(projection: projection),
      ],
    );
  }
}
