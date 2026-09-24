import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_areas_section.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_header.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_kpi_grid.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_category_hours.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_summary_charts.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_monthly_hours.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_area_compliance_panel.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_period_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cumplimientoAsync = ref.watch(cumplimientoDashboardProvider);
    final areasAsync = ref.watch(semaforoPorAreaProvider);
    final cargasAsync = ref.watch(cargasDashboardProvider);
    final equiposAsync = ref.watch(equiposGlobalProvider);
    final alcance = ref.watch(alcancePeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final soloRegistrosCargados = ref.watch(
      soloRegistrosCargadosPeriodoProvider,
    );
    final aniosDisponibles = ref
        .watch(aniosEquipoDisponiblesProvider)
        .maybeWhen(data: (anios) => anios, orElse: () => [anio]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
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
                          soloRegistrosCargados: soloRegistrosCargados,
                          onScopeChanged: (value) {
                            ref.read(alcancePeriodoProvider.notifier).state =
                                value;
                          },
                          onMonthChanged: (value) {
                            if (value == null) return;
                            ref.read(filtroMesPeriodoProvider.notifier).state =
                                value;
                          },
                          onYearChanged: (value) {
                            if (value == null) return;
                            ref.read(filtroAnioPeriodoProvider.notifier).state =
                                value;
                          },
                          onLoadedRecordsChanged: (value) {
                            ref
                                    .read(
                                      soloRegistrosCargadosPeriodoProvider
                                          .notifier,
                                    )
                                    .state =
                                value;
                          },
                        ),
                        const SizedBox(height: 24),
                        DashboardKpiGrid(
                          cumplimientosAsync: cumplimientoAsync,
                          cargasAsync: cargasAsync,
                          areasAsync: areasAsync,
                          equiposAsync: equiposAsync,
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
                        DashboardAreaCompliancePanel(areasAsync: areasAsync),
                        const SizedBox(height: 28),
                        DashboardMonthlyHours(cargasAsync: cargasAsync),
                        const SizedBox(height: 28),
                        DashboardAreasSection(areasAsync: areasAsync),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
