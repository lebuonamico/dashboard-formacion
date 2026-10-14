import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_areas_section.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_header.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_kpi_grid.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_category_hours.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_summary_charts.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_monthly_hours.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_period_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hayDatosAsync = ref.watch(hayDatosEquiposPeriodoProvider);
    final cumplimientoAsync = ref.watch(cumplimientoDashboardProvider);
    final areasAsync = ref.watch(semaforoPorAreaProvider);
    final cargasAsync = ref.watch(cargasDashboardProvider);
    final equiposAsync = ref.watch(equiposGlobalProvider);
    final mesesEvaluados =
        ref.watch(mesesEvaluadosDashboardProvider).value ?? 1;
    final alcance = ref.watch(alcancePeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final aniosDisponibles = ref
        .watch(aniosEquipoDisponiblesProvider)
        .maybeWhen(data: (anios) => anios, orElse: () => [anio]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const DashboardHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EquiposPeriodControls(
                    alcance: alcance,
                    selectedMonth: mes,
                    selectedYear: anio,
                    availableYears: aniosDisponibles,
                    onScopeChanged: (value) {
                      ref.read(alcancePeriodoProvider.notifier).state = value;
                    },
                    onMonthChanged: (value) {
                      if (value == null) return;
                      ref.read(filtroMesPeriodoProvider.notifier).state = value;
                    },
                    onYearChanged: (value) {
                      if (value == null) return;
                      ref.read(filtroAnioPeriodoProvider.notifier).state =
                          value;
                    },
                  ),
                  const SizedBox(height: 24),
                  hayDatosAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text('Error: $error'),
                    data: (hayDatos) => FadeIn(
                      child: (() {
                        if (!hayDatos) {
                          return EmptyDataState.periodoSinDatos(
                            periodo: etiquetaPeriodo(alcance, mes, anio),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DashboardKpiGrid(
                              cumplimientosAsync: cumplimientoAsync,
                              cargasAsync: cargasAsync,
                              areasAsync: areasAsync,
                              equiposAsync: equiposAsync,
                              alcance: alcance,
                              mesSeleccionado: mes,
                              anioSeleccionado: anio,
                              mesesEvaluados: mesesEvaluados,
                            ),
                            const SizedBox(height: 28),
                            DashboardCategoryHours(
                              cumplimientosAsync: cumplimientoAsync,
                            ),
                            const SizedBox(height: 28),
                            DashboardSummaryCharts(
                              cumplimientosAsync: cumplimientoAsync,
                            ),
                            const SizedBox(height: 28),
                            // DashboardAreaCompliancePanel(areasAsync: areasAsync),
                            // const SizedBox(height: 28),
                            DashboardMonthlyHours(cargasAsync: cargasAsync),
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
