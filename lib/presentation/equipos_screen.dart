import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
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

/// Leandro: Pantalla global que el router muestra al entrar en /equipos.
///
/// Leandro: Recorrido para leer esta pantalla:
/// Leandro: 1. Los providers preparan la lista completa y la lista filtrada.
/// Leandro: 2. when decide si mostrar carga, error o _DashboardContent.
/// Leandro: 3. _DashboardContent entrega los datos a cada sección visual.
/// Leandro: 4. Los filtros actualizan Riverpod y este notifica a quienes los observan.
/// Leandro: ConsumerWidget permite usar ref para acceder a Riverpod.
class EquiposScreen extends ConsumerWidget {
  const EquiposScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leandro: watch obtiene el estado y lo observa: si cambia, se reconstruye el widget.
    // Leandro: La lista completa alimenta los indicadores; la filtrada, las tarjetas.
    final equiposAsync = ref.watch(equiposGlobalProvider);
    final equiposFiltradosAsync = ref.watch(equiposGlobalFiltradosProvider);

    // Leandro: build describe la interfaz y puede ejecutarse varias veces.
    // Leandro: Scaffold contiene la pantalla; Row coloca menú y contenido lado a lado.
    return Scaffold(
      backgroundColor: equiposBackground,
      body: Row(
        children: [
          const SideMenu(),
          // Leandro: Expanded ocupa el ancho restante; Column apila barra y contenido.
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                Expanded(
                  // Leandro: AsyncValue representa carga, error o datos disponibles.
                  // Leandro: Cada función de when devuelve el widget de ese estado.
                  child: equiposAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: equiposBrand),
                    ),
                    error: (error, _) => _ErrorState(message: '$error'),
                    data: (equipos) {
                      // Leandro: Lista completa vacía: todavía no hay equipos que mostrar.
                      // Leandro: Es distinto a tener equipos pero cero coincidencias.
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

// Leandro: El prefijo _ hace privada esta clase a la biblioteca de Dart (este archivo).
// Leandro: Coordina las secciones y, por ahora, calcula aquí los totales generales.
class _DashboardContent extends ConsumerWidget {
  final List<EquipoGlobalViewModel> equipos;
  final AsyncValue<List<EquipoGlobalViewModel>> equiposFiltradosAsync;

  // Leandro: required obliga a entregar estos datos al crear el widget.
  // Leandro: final evita reasignar sus campos; const permite instancias constantes.
  const _DashboardContent({
    required this.equipos,
    required this.equiposFiltradosAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leandro: fold recorre la lista acumulando un resultado desde 0.
    // Leandro: Ejemplo: equipos de 3 y 2 integrantes producen un total de 5.
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
    // Leandro: Calculamos el porcentaje con las horas totales, no promediando porcentajes.
    // Leandro: La convención actual devuelve 100 si no hay horas objetivo; evita dividir por 0.
    final cumplimientoGlobal = horasObjetivo == 0
        ? 100.0
        : horasRealizadas / horasObjetivo * 100;
    final equiposEnObjetivo = _countByStatus(EstadoSemaforo.verde);
    final equiposEnRiesgo = _countByStatus(EstadoSemaforo.amarillo);
    final equiposCriticos = _countByStatus(EstadoSemaforo.rojo);
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
    // Leandro: map extrae las áreas; toSet quita repetidas; toList vuelve a crear una lista.
    // Leandro: ..sort() ordena esa misma lista para las opciones del desplegable.
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

    // Leandro: ListView permite desplazar todo el contenido verticalmente.
    // Leandro: Sus children aparecen en el mismo orden en que los escribimos aquí.
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
        // Leandro: Pasamos los totales como parámetros; la sección se ocupa de mostrarlos.
        EquiposKpiSection(
          totalEquipos: equipos.length,
          totalColaboradores: totalColaboradores,
          horasRealizadas: horasRealizadas,
          horasObjetivo: horasObjetivo,
          desvioHoras: desvioHoras,
          cumplimientoGlobal: cumplimientoGlobal,
        ),
        const SizedBox(height: 16),
        // Leandro: Las dos tortas comparan lecturas generales del mismo periodo.
        // Leandro: En escritorio van en la misma fila; en pantallas chicas se apilan.
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
        // Leandro: El widget de filtros recibe valores y funciones (callbacks).
        // Leandro: Los controles llaman a estas funciones cuando el usuario los modifica.
        EquiposFilters(
          areas: areas,
          searchText: busqueda,
          selectedArea: areaSeleccionada,
          selectedStatus: estadoSeleccionado,
          hasActiveFilters: hayFiltrosActivos,
          onSearch: (value) {
            // Leandro: read accede sin suscribirse; notifier permite cambiar el estado.
            // Leandro: Guardar el texto hace que el provider de filtrados se recalcule.
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
        // Leandro: Sólo los resultados reciben la lista filtrada. Si queda vacía,
        // Leandro: EquiposResults muestra un mensaje y los KPI de arriba se conservan.
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

  int _countByStatus(EstadoSemaforo status) {
    // Leandro: where conserva los equipos del estado indicado; length cuenta cuántos son.
    return equipos.where((equipo) => equipo.semaforo == status).length;
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

// Leandro: Cabecera con el mismo diseño que las demás pantallas.
// Leandro: StatelessWidget puede reconstruirse; no administra un estado mutable propio.
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

// Leandro: Estado de la pantalla cuando la lista completa no tiene equipos.
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

// Leandro: Recibe el error del provider para que una falla tenga un mensaje visible.
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
