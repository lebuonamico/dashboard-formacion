import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_category_distribution.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_filters.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_period_controls.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_results.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_status_summary.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';

class AreasScreen extends ConsumerWidget {
  const AreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenAreasPeriodoProvider);
    final areasFiltradasAsync = ref.watch(areasFiltradasProvider);
    final requestedOrigin = GoRouterState.of(
      context,
    ).uri.queryParameters['origen'];
    const validOrigins = {'dashboard', 'areas', 'equipos'};
    final origin = validOrigins.contains(requestedOrigin)
        ? requestedOrigin
        : null;

    return Scaffold(
      backgroundColor: areasBackground,
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                const AppTopBar(title: 'Áreas y equipos generales'),
                Expanded(
                  child: resumenAsync.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: areasBrand),
                    ),
                    error: (error, _) => _ErrorState(message: '$error'),
                    data: (resumen) => _AreasContent(
                      resumen: resumen,
                      areasFiltradasAsync: areasFiltradasAsync,
                      origin: origin,
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

class _AreasContent extends ConsumerWidget {
  final ResumenAreasPeriodo resumen;
  final AsyncValue<List<AreaGlobalViewModel>> areasFiltradasAsync;
  final String? origin;

  const _AreasContent({
    required this.resumen,
    required this.areasFiltradasAsync,
    required this.origin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = resumen.areas;
    final busqueda = ref.watch(busquedaAreaProvider);
    final estadoSeleccionado = ref.watch(filtroEstadoAreaProvider);
    final alcanceSeleccionado = ref.watch(alcancePeriodoProvider);
    final mesSeleccionado = ref.watch(filtroMesPeriodoProvider);
    final anioSeleccionado = ref.watch(filtroAnioPeriodoProvider);
    final aniosDisponibles = ref
        .watch(aniosEquipoDisponiblesProvider)
        .maybeWhen(data: (anios) => anios, orElse: () => [anioSeleccionado]);
    final esAnual = alcanceSeleccionado == AlcancePeriodo.anual;
    final hayFiltrosActivos =
        busqueda.trim().isNotEmpty || estadoSeleccionado != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        const Text(
          'Vista general',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: areasInk,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          resumen.tieneDatos
              ? 'Seguimiento del avance de ${areas.length} áreas de formación.'
              : 'Seleccioná un período con datos cargados.',
          style: const TextStyle(fontSize: 14, color: areasMuted),
        ),
        const SizedBox(height: 18),
        AreasPeriodControls(
          alcance: alcanceSeleccionado,
          selectedMonth: mesSeleccionado,
          selectedYear: anioSeleccionado,
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
            ref.read(filtroAnioPeriodoProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 22),
        if (!resumen.tieneDatos)
          EmptyDataState.periodoSinDatos(
            icon: Icons.apartment_outlined,
            periodo: etiquetaPeriodo(
              alcanceSeleccionado,
              mesSeleccionado,
              anioSeleccionado,
            ),
          )
        else if (areas.isEmpty)
          const EmptyDataState(
            icon: Icons.apartment_outlined,
            title: 'No hay áreas con colaboradores elegibles en este período.',
            message:
                'Verificá la nómina elegible para el período seleccionado.',
          )
        else ...[
          AreasKpiSection(
            totalAreas: resumen.totalAreas,
            totalColaboradores: resumen.colaboradores,
            horasRealizadas: resumen.horasRealizadas,
            horasObjetivo: resumen.horasObjetivo,
            desvioHoras: resumen.desvioHoras,
            cumplimientoGlobal: resumen.cumplimientoGlobal,
            esAnual: esAnual,
          ),
          const SizedBox(height: 16),
          _ChartsRow(
            statusChart: AreasStatusSummary(
              total: resumen.totalAreas,
              enObjetivo: resumen.enObjetivo,
              enRiesgo: resumen.enRiesgo,
              criticos: resumen.criticos,
            ),
            categoryChart: AreasCategoryDistribution(
              horasNegocio: resumen.horasNegocio,
              horasBlandas: resumen.horasBlandas,
              horasLibres: resumen.horasLibres,
              horasDictado: resumen.horasDictado,
              esAnual: esAnual,
            ),
          ),
          const SizedBox(height: 24),
          AreasFilters(
            searchText: busqueda,
            selectedStatus: estadoSeleccionado,
            hasActiveFilters: hayFiltrosActivos,
            onSearch: (value) {
              ref.read(busquedaAreaProvider.notifier).state = value;
            },
            onStatus: (value) {
              ref.read(filtroEstadoAreaProvider.notifier).state = value;
            },
            onClear: () {
              ref.read(busquedaAreaProvider.notifier).state = '';
              ref.read(filtroEstadoAreaProvider.notifier).state = null;
            },
          ),
          const SizedBox(height: 24),
          areasFiltradasAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: areasBrand),
            ),
            error: (error, _) => _ErrorState(message: '$error'),
            data: (areasFiltradas) => AreasResults(
              key: ValueKey(
                '$alcanceSeleccionado-$anioSeleccionado-$mesSeleccionado-'
                '$busqueda-$estadoSeleccionado',
              ),
              areas: areasFiltradas,
              totalAreas: resumen.totalAreas,
              esAnual: esAnual,
              origen: origin,
            ),
          ),
        ],
      ],
    );
  }
}

/// Estado y categorías lado a lado; en pantallas angostas, uno debajo del otro.
class _ChartsRow extends StatelessWidget {
  final Widget statusChart;
  final Widget categoryChart;

  const _ChartsRow({required this.statusChart, required this.categoryChart});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1180) {
          return Column(
            children: [statusChart, const SizedBox(height: 16), categoryChart],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: statusChart),
              const SizedBox(width: 16),
              Expanded(child: categoryChart),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No pudimos cargar las áreas.\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
