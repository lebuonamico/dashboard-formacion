import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_areas_section.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_kpi_grid.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_summary_charts.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_monthly_hours.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/moodle_crm_comparison_cards.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/reports/presentation/widgets/print_report_button.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Plan Q3 - formación interna'),
          Expanded(
            child: SingleChildScrollView(
              padding: screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PeriodFilterPanel(
                    action: PrintReportButton(report: dashboardReportProvider),
                  ),
                  const SizedBox(height: 24),
                  ref
                      .watch(hasTeamPeriodDataProvider)
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => ErrorDataState(
                          title: 'No pudimos cargar el tablero',
                          error: error,
                          onRetry: () =>
                              ref.invalidate(hasTeamPeriodDataProvider),
                        ),
                        data: (hasData) => FadeIn(
                          child: hasData
                              ? const _DashboardContent()
                              : EmptyDataState.periodWithoutData(
                                  period: periodLabel(
                                    period.scope,
                                    period.month,
                                    period.year,
                                  ),
                                ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);
    const wholePayroll = (area: null, team: null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardKpiGrid(
          kpisAsync: ref.watch(dashboardKpisProvider),
          scope: period.scope,
          selectedMonth: period.month,
          selectedYear: period.year,
          projectionAsync: ref.watch(annualProjectionProvider(wholePayroll)),
          variationAsync: ref.watch(complianceVariationProvider(wholePayroll)),
          onRetry: () => ref.invalidate(dashboardKpisProvider),
        ),
        const SizedBox(height: 28),
        DashboardSummaryCharts(
          distributionAsync: ref.watch(dashboardDistributionProvider),
          onRetry: () => ref.invalidate(dashboardDistributionProvider),
        ),
        const SizedBox(height: 28),
        if (ref.watch(dashboardComplianceProvider).value case final items?
            when items.isNotEmpty) ...[
          MoodleCrmComparisonCards(complianceList: items),
          const SizedBox(height: 28),
        ],
        DashboardMonthlyHours(
          evolutionAsync: ref.watch(dashboardMonthlyEvolutionProvider),
          onRetry: () => ref.invalidate(dashboardMonthlyEvolutionProvider),
        ),
        const SizedBox(height: 28),
        const DashboardAreasSection(),
      ],
    );
  }
}
