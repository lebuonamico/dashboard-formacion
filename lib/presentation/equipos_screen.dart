import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_category_distribution.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_filters.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_period_controls.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_results.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_status_summary.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Leandro: Pantalla principal de /equipos.
/// Flujo: observa los providers, resuelve carga/error y envía los datos a cada widget.
class EquiposScreen extends ConsumerWidget {
  const EquiposScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leandro: La lista completa alimenta los indicadores; la filtrada, las tarjetas.
    final equiposAsync = ref.watch(equiposGlobalProvider);
    final equiposFiltradosAsync = ref.watch(equiposGlobalFiltradosProvider);

    return Scaffold(
      backgroundColor: equiposBackground,
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                Expanded(
                  // Leandro: Según el provider, muestra carga, error o el dashboard.
                  child: equiposAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: equiposBrand),
                    ),
                    error: (error, _) => _ErrorState(message: '$error'),
                    data: (equipos) {
                      // Leandro: Sin equipos cargados se muestra el estado vacío general.
                      if (equipos.isEmpty) {
                        return const _EmptyDataState();
                      }

                      return _DashboardContent(
                        equipos: equipos,
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

// Leandro: Coordina los widgets del dashboard y calcula sus totales generales.
class _DashboardContent extends ConsumerWidget {
  final List<EquipoGlobalViewModel> equipos;
  final AsyncValue<List<EquipoGlobalViewModel>> equiposFiltradosAsync;

  const _DashboardContent({
    required this.equipos,
    required this.equiposFiltradosAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leandro: Siempre usamos la lista completa para que los KPI no cambien al filtrar.
    final totalColaboradores = equipos.fold<int>(
      0,
      (total, equipo) => total + equipo.cantidadIntegrantes,
    );
    final horasRealizadas = equipos.fold<double>(
      0,
      (total, equipo) => total + equipo.horasRealizadas,
    );
    final horasObjetivo = equipos.fold<double>(
      0,
      (total, equipo) => total + equipo.horasObjetivo,
    );
    final desvioHoras = horasRealizadas - horasObjetivo;
    // Leandro: El cumplimiento global surge de horas totales, no del promedio de porcentajes.
    final cumplimientoGlobal = horasObjetivo == 0
        ? 100.0
        : horasRealizadas / horasObjetivo * 100;
    final equiposEnObjetivo = _countByStatus(EstadoEquipo.enObjetivo);
    final equiposEnRiesgo = _countByStatus(EstadoEquipo.enRiesgo);
    final equiposCriticos = _countByStatus(EstadoEquipo.critico);
    final horasNegocio = equipos.fold<double>(
      0,
      (total, equipo) => total + equipo.horasNegocio,
    );
    final horasBlandas = equipos.fold<double>(
      0,
      (total, equipo) => total + equipo.horasBlandas,
    );
    final horasLibres = equipos.fold<double>(
      0,
      (total, equipo) => total + equipo.horasLibres,
    );
    final horasDictado = equipos.fold<double>(
      0,
      (total, equipo) => total + equipo.horasDictado,
    );
    // Leandro: Estas áreas únicas alimentan el selector del widget EquiposFilters.
    final areas = equipos.map((equipo) => equipo.area).toSet().toList()..sort();
    final busqueda = ref.watch(busquedaEquipoProvider);
    final areaSeleccionada = ref.watch(filtroAreaEquipoProvider);
    final estadoSeleccionado = ref.watch(filtroEstadoEquipoProvider);
    final alcanceSeleccionado = ref.watch(alcancePeriodoEquipoProvider);
    final mesSeleccionado = ref.watch(filtroMesEquipoProvider);
    final anioSeleccionado = ref.watch(filtroAnioEquipoProvider);
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
          onScopeChanged: (value) {
            if (value == null) return;
            ref.read(alcancePeriodoEquipoProvider.notifier).state = value;
          },
          onMonthChanged: (value) {
            if (value == null) return;
            ref.read(filtroMesEquipoProvider.notifier).state = value;
          },
          onYearChanged: (value) {
            if (value == null) return;
            ref.read(filtroAnioEquipoProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 22),
        // Leandro: EquiposKpiSection muestra los cuatro indicadores generales.
        EquiposKpiSection(
          totalEquipos: equipos.length,
          totalColaboradores: totalColaboradores,
          horasRealizadas: horasRealizadas,
          horasObjetivo: horasObjetivo,
          desvioHoras: desvioHoras,
          cumplimientoGlobal: cumplimientoGlobal,
        ),
        const SizedBox(height: 16),
        // Leandro: _DashboardChartsRow muestra los dos donuts del período seleccionado.
        _DashboardChartsRow(
          statusChart: EquiposStatusSummary(
            total: equipos.length,
            enObjetivo: equiposEnObjetivo,
            enRiesgo: equiposEnRiesgo,
            criticos: equiposCriticos,
          ),
          categoryChart: EquiposCategoryDistribution(
            horasNegocio: horasNegocio,
            horasBlandas: horasBlandas,
            horasLibres: horasLibres,
            horasDictado: horasDictado,
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
            equipos: equiposFiltrados,
            totalEquipos: equipos.length,
          ),
        ),
      ],
    );
  }

  int _countByStatus(EstadoEquipo status) {
    return equipos.where((equipo) => equipo.estado == status).length;
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

// Leandro: Cabecera visual de la pantalla de Equipos.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: equiposBorder)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Dashboard Global de Equipos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: equiposInk,
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: equiposBrand,
            child: Text('U', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Leandro: Se muestra cuando la lista completa no contiene equipos.
class _EmptyDataState extends StatelessWidget {
  const _EmptyDataState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 34, color: equiposMuted),
          SizedBox(height: 10),
          Text(
            'No hay equipos para mostrar.',
            style: TextStyle(fontWeight: FontWeight.w700, color: equiposInk),
          ),
          SizedBox(height: 4),
          Text(
            'Revisá que existan empleados con equipo asignado, cursos y cargas CRM.',
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
