import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_category_distribution.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_filters.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_period_controls.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_results.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_status_summary.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Leandro: Pantalla principal de /equipos.
/// Flujo: observa los providers, resuelve carga/error y envía los datos a cada widget.
class EquiposScreen extends ConsumerWidget {
  const EquiposScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leandro: El resumen completo alimenta indicadores y donuts; el filtro, las tarjetas.
    final resumenAsync = ref.watch(resumenEquiposPeriodoProvider);
    final equiposFiltradosAsync = ref.watch(equiposGlobalFiltradosProvider);

    return Scaffold(
      backgroundColor: equiposBackground,
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                const AppTopBar(title: 'Dashboard global de equipos'),
                Expanded(
                  // Leandro: Según el provider, muestra carga, error o el dashboard.
                  child: resumenAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: equiposBrand),
                    ),
                    error: (error, _) => _ErrorState(message: '$error'),
                    data: (resumen) {
                      return _DashboardContent(
                        resumen: resumen,
                        equiposFiltradosAsync: equiposFiltradosAsync,
                      );
                    },
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

// Leandro: Coordina los widgets; los cálculos ya llegan resueltos por el servicio.
class _DashboardContent extends ConsumerWidget {
  final ResumenEquiposPeriodo resumen;
  final AsyncValue<List<EquipoGlobalViewModel>> equiposFiltradosAsync;

  const _DashboardContent({
    required this.resumen,
    required this.equiposFiltradosAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipos = resumen.equipos;
    // Leandro: Estas áreas únicas alimentan el selector del widget EquiposFilters.
    final areas = equipos.map((equipo) => equipo.area).toSet().toList()..sort();
    final busqueda = ref.watch(busquedaEquipoProvider);
    final areaSeleccionada = ref.watch(filtroAreaEquipoProvider);
    final estadoSeleccionado = ref.watch(filtroEstadoEquipoProvider);
    final alcanceSeleccionado = ref.watch(alcancePeriodoProvider);
    final mesSeleccionado = ref.watch(filtroMesPeriodoProvider);
    final anioSeleccionado = ref.watch(filtroAnioPeriodoProvider);
    final soloRegistrosCargados = ref.watch(
      soloRegistrosCargadosPeriodoProvider,
    );
    final aniosDisponibles = ref
        .watch(aniosEquipoDisponiblesProvider)
        .maybeWhen(data: (anios) => anios, orElse: () => [anioSeleccionado]);
    final hayFiltrosActivos =
        busqueda.trim().isNotEmpty ||
        areaSeleccionada != null ||
        estadoSeleccionado != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        const Text(
          'Vista general',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: equiposInk,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Seguimiento del avance de ${equipos.length} equipos de formación.',
          style: const TextStyle(fontSize: 14, color: equiposMuted),
        ),
        const SizedBox(height: 18),
        EquiposPeriodControls(
          alcance: alcanceSeleccionado,
          selectedMonth: mesSeleccionado,
          selectedYear: anioSeleccionado,
          availableYears: aniosDisponibles,
          soloRegistrosCargados: soloRegistrosCargados,
          onScopeChanged: (value) {
            ref.read(alcancePeriodoProvider.notifier).state = value;
            ref.read(filtroAreaEquipoProvider.notifier).state = null;
          },
          onMonthChanged: (value) {
            if (value == null) return;
            ref.read(filtroMesPeriodoProvider.notifier).state = value;
            ref.read(filtroAreaEquipoProvider.notifier).state = null;
          },
          onYearChanged: (value) {
            if (value == null) return;
            ref.read(filtroAnioPeriodoProvider.notifier).state = value;
            ref.read(filtroAreaEquipoProvider.notifier).state = null;
          },
          onLoadedRecordsChanged: (value) {
            ref.read(soloRegistrosCargadosPeriodoProvider.notifier).state =
                value;
            ref.read(filtroAreaEquipoProvider.notifier).state = null;
          },
        ),
        const SizedBox(height: 22),
        if (equipos.isEmpty)
          const _EmptyDataState()
        else ...[
          // Leandro: EquiposKpiSection muestra los cuatro indicadores generales.
          EquiposKpiSection(
            totalEquipos: resumen.totalEquipos,
            totalColaboradores: resumen.colaboradores,
            horasRealizadas: resumen.horasRealizadas,
            horasObjetivo: resumen.horasObjetivo,
            desvioHoras: resumen.desvioHoras,
            cumplimientoGlobal: resumen.cumplimientoGlobal,
          ),
          const SizedBox(height: 16),
          // Leandro: _DashboardChartsRow muestra los dos donuts del período seleccionado.
          _DashboardChartsRow(
            statusChart: EquiposStatusSummary(
              total: resumen.totalEquipos,
              enObjetivo: resumen.enObjetivo,
              enRiesgo: resumen.enRiesgo,
              criticos: resumen.criticos,
            ),
            categoryChart: EquiposCategoryDistribution(
              horasNegocio: resumen.horasNegocio,
              horasBlandas: resumen.horasBlandas,
              horasLibres: resumen.horasLibres,
              horasDictado: resumen.horasDictado,
            ),
          ),
          const SizedBox(height: 24),
          // Leandro: EquiposFilters actualiza los providers de búsqueda, área y estado.
          EquiposFilters(
            areas: areas,
            searchText: busqueda,
            selectedArea: areaSeleccionada,
            selectedStatus: estadoSeleccionado,
            hasActiveFilters: hayFiltrosActivos,
            onSearch: (value) {
              ref.read(busquedaEquipoProvider.notifier).state = value;
            },
            onArea: (value) {
              ref.read(filtroAreaEquipoProvider.notifier).state = value;
            },
            onStatus: (value) {
              ref.read(filtroEstadoEquipoProvider.notifier).state = value;
            },
            onClear: () {
              ref.read(busquedaEquipoProvider.notifier).state = '';
              ref.read(filtroAreaEquipoProvider.notifier).state = null;
              ref.read(filtroEstadoEquipoProvider.notifier).state = null;
            },
          ),
          const SizedBox(height: 24),
          // Leandro: EquiposResults recibe sólo las tarjetas que cumplen los filtros.
          equiposFiltradosAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: equiposBrand),
            ),
            error: (error, _) => _ErrorState(message: '$error'),
            data: (equiposFiltrados) => EquiposResults(
              key: ValueKey(
                '$alcanceSeleccionado-$anioSeleccionado-$mesSeleccionado-'
                '$soloRegistrosCargados-$busqueda-$areaSeleccionada-'
                '$estadoSeleccionado',
              ),
              equipos: equiposFiltrados,
              totalEquipos: resumen.totalEquipos,
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardChartsRow extends StatelessWidget {
  final Widget statusChart;
  final Widget categoryChart;

  const _DashboardChartsRow({
    required this.statusChart,
    required this.categoryChart,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1180) {
          return Column(
            children: [statusChart, const SizedBox(height: 16), categoryChart],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: statusChart),
            const SizedBox(width: 16),
            Expanded(child: categoryChart),
          ],
        );
      },
    );
  }
}

// Leandro: Se muestra cuando la lista completa no contiene equipos.
class _EmptyDataState extends StatelessWidget {
  const _EmptyDataState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      decoration: equiposPanelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.groups_outlined, size: 34, color: equiposMuted),
          SizedBox(height: 10),
          Text(
            'No hay equipos activos en este período.',
            style: TextStyle(fontWeight: FontWeight.w700, color: equiposInk),
          ),
          SizedBox(height: 4),
          Text(
            'Probá otro mes o verificá que existan cargas CRM o finalizaciones LMS.',
            style: TextStyle(color: equiposMuted),
          ),
        ],
      ),
    );
  }
}

// Leandro: Muestra al usuario el error informado por el provider.
class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No pudimos cargar los equipos.\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
