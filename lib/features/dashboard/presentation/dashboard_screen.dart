import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/area_compliance_providers.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:app_finnegans/core/period/period_formatter.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_areas_section.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_kpi_grid.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_summary_charts.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_monthly_hours.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/moodle_crm_comparison_cards.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/reports/presentation/widgets/print_report_button.dart';
import 'package:app_finnegans/core/period/period_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDataAsync = ref.watch(hasTeamPeriodDataProvider);
    final complianceAsync = ref.watch(dashboardComplianceProvider);
    final areasAsync = ref.watch(complianceByAreaProvider);
    final timeEntriesAsync = ref.watch(dashboardTimeEntriesProvider);
    final teamsAsync = ref.watch(teamOverviewsProvider);
    final evaluatedMonths =
        ref.watch(dashboardEvaluatedMonthsProvider).value ?? 1;
    final scope = ref.watch(periodScopeProvider);
    final month = ref.watch(periodMonthFilterProvider);
    final year = ref.watch(periodYearFilterProvider);

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
                  hasDataAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ErrorDataState(
                      title: 'No pudimos cargar el tablero',
                      error: error,
                    ),
                    data: (hasData) => FadeIn(
                      child: (() {
                        if (!hasData) {
                          return EmptyDataState.periodWithoutData(
                            period: periodLabel(scope, month, year),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DashboardKpiGrid(
                              complianceListAsync: complianceAsync,
                              timeEntriesAsync: timeEntriesAsync,
                              areasAsync: areasAsync,
                              teamsAsync: teamsAsync,
                              scope: scope,
                              selectedMonth: month,
                              selectedYear: year,
                              evaluatedMonths: evaluatedMonths,
                              projectionAsync: ref.watch(
                                annualProjectionProvider((
                                  area: null,
                                  team: null,
                                )),
                              ),
                              variationAsync: ref.watch(
                                complianceVariationProvider((
                                  area: null,
                                  team: null,
                                )),
                              ),
                            ),
                            const SizedBox(height: 28),
                            DashboardSummaryCharts(
                              complianceListAsync: complianceAsync,
                            ),
                            const SizedBox(height: 28),
                            if (complianceAsync.value case final items?
                                when items.isNotEmpty) ...[
                              MoodleCrmComparisonCards(complianceList: items),
                              const SizedBox(height: 28),
                            ],
                            DashboardMonthlyHours(
                              evolutionAsync: ref.watch(
                                dashboardMonthlyEvolutionProvider,
                              ),
                            ),
                            const SizedBox(height: 28),
                            DashboardAreasSection(areasAsync: areasAsync),
                          ],
                        );
                      })(),
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
