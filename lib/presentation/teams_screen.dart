import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
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

class EquiposScreen extends ConsumerWidget {
  const EquiposScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leandro: llama a resumenEquiposPeriodoProvider para obtener los indicadores y el estado de datos del período.
    final resumenAsync = ref.watch(resumenEquiposPeriodoProvider);
    // Leandro: llama a equiposGlobalFiltradosProvider para obtener los equipos que coinciden con los filtros.
    final equiposFiltradosAsync = ref.watch(equiposGlobalFiltradosProvider);

    return Scaffold(
      backgroundColor: equiposBackground,
      body: Row(
        children: [
          // Leandro: llama al widget SideMenu para mostrar la navegación de la aplicación.
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                // Leandro: llama al widget AppTopBar para mostrar el título de la pantalla de Equipos.
                const AppTopBar(title: 'Dashboard global de equipos'),
                Expanded(
                  // Leandro: llama a AsyncValue.when para mostrar la carga, el error o el contenido del período.
                  child: resumenAsync.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: equiposBrand),
                    ),
                    error: (error, _) => _ErrorState(message: '$error'),
                    data: (resumen) {
                      // Leandro: llama al widget _DashboardContent para presentar el resumen y los equipos filtrados.
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
    final areas = equipos.map((equipo) => equipo.area).toSet().toList()..sort();
    final busqueda = ref.watch(busquedaEquipoProvider);
    final areaSeleccionada = ref.watch(filtroAreaEquipoProvider);
    final estadoSeleccionado = ref.watch(filtroEstadoEquipoProvider);
    final alcanceSeleccionado = ref.watch(alcancePeriodoProvider);
    final mesSeleccionado = ref.watch(filtroMesPeriodoProvider);
    final anioSeleccionado = ref.watch(filtroAnioPeriodoProvider);
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
          resumen.tieneDatos
              ? 'Seguimiento del avance de ${equipos.length} equipos de formación.'
              : 'Seleccioná un período con datos cargados.',
          style: const TextStyle(fontSize: 14, color: equiposMuted),
        ),
        const SizedBox(height: 18),
        // Leandro: llama al widget EquiposPeriodControls para elegir el mes, el año y el alcance de los indicadores.
        EquiposPeriodControls(
          alcance: alcanceSeleccionado,
          selectedMonth: mesSeleccionado,
          selectedYear: anioSeleccionado,
          availableYears: aniosDisponibles,
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
        ),
        const SizedBox(height: 22),
        if (!resumen.tieneDatos)
          // Leandro: llama al widget _EmptyDataState para informar que el período seleccionado no tiene registros.
          _EmptyDataState(
            periodoSinDatos: alcanceSeleccionado == AlcancePeriodo.anual
                ? '$anioSeleccionado'
                : '${nombreMes(mesSeleccionado)} $anioSeleccionado',
          )
        else if (equipos.isEmpty)
          // Leandro: llama al widget _EmptyDataState para informar que no hay equipos con colaboradores elegibles.
          const _EmptyDataState()
        else ...[
          // Leandro: llama al widget EquiposKpiSection para mostrar equipos, colaboradores, horas y cumplimiento global.
          EquiposKpiSection(
            totalEquipos: resumen.totalEquipos,
            totalColaboradores: resumen.colaboradores,
            horasRealizadas: resumen.horasRealizadas,
            horasObjetivo: resumen.horasObjetivo,
            desvioHoras: resumen.desvioHoras,
            cumplimientoGlobal: resumen.cumplimientoGlobal,
            esAnual: alcanceSeleccionado == AlcancePeriodo.anual,
          ),
          const SizedBox(height: 16),
          // Leandro: llama al widget _DashboardChartsRow para organizar los gráficos de estados y categorías.
          _DashboardChartsRow(
            // Leandro: llama al widget EquiposStatusSummary para mostrar cuántos equipos hay en cada estado.
            statusChart: EquiposStatusSummary(
              total: resumen.totalEquipos,
              enObjetivo: resumen.enObjetivo,
              enRiesgo: resumen.enRiesgo,
              criticos: resumen.criticos,
            ),
            // Leandro: llama al widget EquiposCategoryDistribution para mostrar las horas válidas por categoría.
            categoryChart: EquiposCategoryDistribution(
              horasNegocio: resumen.horasNegocio,
              horasBlandas: resumen.horasBlandas,
              horasLibres: resumen.horasLibres,
              horasDictado: resumen.horasDictado,
              esAnual: alcanceSeleccionado == AlcancePeriodo.anual,
            ),
          ),
          const SizedBox(height: 24),
          // Leandro: llama al widget EquiposFilters para actualizar la búsqueda y los filtros de área y estado.
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
          equiposFiltradosAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: equiposBrand),
            ),
            error: (error, _) => _ErrorState(message: '$error'),
            // Leandro: llama al widget EquiposResults para mostrar y paginar las tarjetas de los equipos filtrados.
            data: (equiposFiltrados) => EquiposResults(
              key: ValueKey(
                '$alcanceSeleccionado-$anioSeleccionado-$mesSeleccionado-'
                '$busqueda-$areaSeleccionada-'
                '$estadoSeleccionado',
              ),
              equipos: equiposFiltrados,
              totalEquipos: resumen.totalEquipos,
              esAnual: alcanceSeleccionado == AlcancePeriodo.anual,
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

// Distingue un período sin registros de una nómina sin equipos elegibles.
class _EmptyDataState extends StatelessWidget {
  final String? periodoSinDatos;

  const _EmptyDataState({this.periodoSinDatos});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      decoration: equiposPanelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 34, color: equiposMuted),
          const SizedBox(height: 10),
          Text(
            periodoSinDatos != null
                ? 'No hay datos cargados para $periodoSinDatos.'
                : 'No hay equipos con colaboradores elegibles en este período.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: equiposInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            periodoSinDatos != null
                ? 'Probá otro período o cargá información CRM/LMS para evaluarlo.'
                : 'Verificá la nómina elegible para el período seleccionado.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: equiposMuted),
          ),
        ],
      ),
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
          'No pudimos cargar los equipos.\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
