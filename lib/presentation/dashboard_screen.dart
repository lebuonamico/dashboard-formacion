import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_areas_section.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_kpi_grid.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_summary_charts.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_monthly_hours.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/comparacion_moodle_crm.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/boton_imprimir_reporte.dart';
import 'package:app_finnegans/presentation/widgets/shared/periodo_filter_panel.dart';
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
