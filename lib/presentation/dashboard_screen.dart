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

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Plan Q3 - formación interna'),
          Expanded(
            child: SingleChildScrollView(
              padding: paddingPantalla,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PeriodoFilterPanel(
                    accion: BotonImprimirReporte(
                      reporte: reporteDashboardProvider,
                    ),
                  ),
                  const SizedBox(height: 24),
                  hayDatosAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ErrorDataState(
                      title: 'No pudimos cargar el tablero',
                      error: error,
                    ),
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
                              proyeccionAsync: ref.watch(
                                proyeccionAnualProvider((
                                  area: null,
                                  equipo: null,
                                )),
                              ),
                              variacionAsync: ref.watch(
                                variacionCumplimientoProvider((
                                  area: null,
                                  equipo: null,
                                )),
                              ),
                            ),
                            const SizedBox(height: 28),
                            DashboardSummaryCharts(
                              cumplimientosAsync: cumplimientoAsync,
                            ),
                            const SizedBox(height: 28),
                            if (cumplimientoAsync.value case final items?
                                when items.isNotEmpty) ...[
                              ComparacionMoodleCrmCards(cumplimientos: items),
                              const SizedBox(height: 28),
                            ],
                            DashboardMonthlyHours(
                              evolucionAsync: ref.watch(
                                evolucionMensualDashboardProvider,
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
