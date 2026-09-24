import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/equipo_global.dart';
import 'package:app_finnegans/domain/modelos/estado_equipo.dart';
import 'package:app_finnegans/domain/servicios/equipos_service.dart';
//import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/periodo_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

export 'package:app_finnegans/domain/modelos/equipo_global.dart';
export 'package:app_finnegans/domain/modelos/estado_equipo.dart';
export 'package:app_finnegans/presentation/providers/periodo_providers.dart';

// Leandro: La primera sección contiene el flujo del dashboard de Equipos.
// Al final permanecen los providers anteriores que usan Áreas y el detalle.

class ResumenEquipoViewModel {
  final String nombreArea;
  final int cantidadIntegrantes;
  final int integrantesCumplen;
  final double horasTotalesRealizadas;
  final double horasTotalesRequeridas;
  final double porcentajeCumplimiento;
  final EstadoSemaforo semaforo;
  final List<String> equiposGenerales;

  ResumenEquipoViewModel({
    required this.nombreArea,
    required this.cantidadIntegrantes,
    required this.integrantesCumplen,
    required this.horasTotalesRealizadas,
    required this.horasTotalesRequeridas,
    required this.porcentajeCumplimiento,
    required this.semaforo,
    required this.equiposGenerales,
  });
}

class DetalleEquipoViewModel {
  final String nombreArea;
  final ResumenEquipoViewModel resumen;
  final List<CumplimientoEmpleado> miembros;
  final Map<String, List<CumplimientoEmpleado>> miembrosPorEquipo;

  DetalleEquipoViewModel({
    required this.nombreArea,
    required this.resumen,
    required this.miembros,
    required this.miembrosPorEquipo,
  });
}

class DetalleEquipoGeneralViewModel {
  final String nombreArea;
  final String nombreEquipo;
  final List<CumplimientoEmpleado> miembros;

  DetalleEquipoGeneralViewModel({
    required this.nombreArea,
    required this.nombreEquipo,
    required this.miembros,
  });
}

// Leandro: Estado de los filtros. La búsqueda también es utilizada por la pantalla de Áreas.
final busquedaEquipoProvider = StateProvider<String>((ref) => '');
final filtroAreaEquipoProvider = StateProvider<String?>((ref) => null);
final filtroEstadoEquipoProvider = StateProvider<EstadoEquipo?>((ref) => null);

/// Leandro: Expone el servicio que concentra las reglas de cálculo de Equipos.
final equiposServiceProvider = Provider<EquiposService>((ref) {
  return EquiposService();
});

final aniosEquipoDisponiblesProvider = FutureProvider<List<int>>((ref) async {
  final cargasDeHoras = await ref.watch(cargasDeHorasCRMProvider.future);
  final anios = cargasDeHoras.map((carga) => carga.fecha.year).toSet()
    ..add(DateTime.now().year);
  final lista = anios.toList()..sort((a, b) => b.compareTo(a));

  return lista;
});

/// Leandro: Arma el cumplimiento por persona para el período seleccionado.
/// Llama a CumplimientoService y luego ajusta el objetivo si la vista es anual.
final cumplimientoEquiposProvider = FutureProvider<List<CumplimientoEmpleado>>((
  ref,
) async {
  final empleados = await ref.watch(empleadosProvider.future);
  final cursos = await ref.watch(cursosProvider.future);
  final cargasDeHoras = await ref.watch(cargasDeHorasCRMProvider.future);
  final alcance = ref.watch(alcancePeriodoProvider);
  final mes = ref.watch(filtroMesPeriodoProvider);
  final anio = ref.watch(filtroAnioPeriodoProvider);
  final soloRegistrosCargados = ref.watch(soloRegistrosCargadosPeriodoProvider);
  final cumplimientoService = ref.read(cumplimientoServiceProvider);
  final equiposService = ref.read(equiposServiceProvider);

  final cargasFiltradas = soloRegistrosCargados
      ? cargasDeHoras
      : equiposService.filtrarCargasPorPeriodo(
          cargas: cargasDeHoras,
          anio: anio,
          mes: mes,
          esAnual: alcance == AlcancePeriodo.anual,
        );

  final cumplimientos = cumplimientoService.calcularCumplimientoGlobal(
    empleados: empleados,
    cursos: cursos,
    cargasDeHoras: cargasFiltradas,
  );

  if (alcance == AlcancePeriodo.mensual || soloRegistrosCargados) {
    return cumplimientos;
  }

  return equiposService.convertirObjetivoMensualAAnual(cumplimientos);
});

/// Leandro: Pasa los cumplimientos a EquiposService y devuelve los equipos calculados.
/// Esta lista completa alimenta KPI y gráficos antes de aplicar filtros visuales.
final equiposGlobalProvider = FutureProvider<List<EquipoGlobalViewModel>>((
  ref,
) async {
  final cumplimientos = await ref.watch(cumplimientoEquiposProvider.future);
  final equiposService = ref.read(equiposServiceProvider);
  return equiposService.calcularEquiposGlobales(cumplimientos);
});

/// Leandro: Filtra la lista calculada por búsqueda, área y estado para las tarjetas.
final equiposGlobalFiltradosProvider =
    Provider<AsyncValue<List<EquipoGlobalViewModel>>>((ref) {
      final areaSeleccionada = ref.watch(filtroAreaEquipoProvider);
      final estadoSeleccionado = ref.watch(filtroEstadoEquipoProvider);
      final equiposAsync = ref.watch(equiposGlobalProvider);
      final query = ref.watch(busquedaEquipoProvider).trim().toLowerCase();

      // Leandro: Si los datos todavía cargan o fallan, AsyncValue conserva ese estado.
      return equiposAsync.whenData((equipos) {
        return equipos.where((equipo) {
          final coincideBusqueda =
              query.isEmpty ||
              equipo.nombre.toLowerCase().contains(query) ||
              equipo.area.toLowerCase().contains(query) ||
              equipo.lider.toLowerCase().contains(query);

          final coincideArea =
              areaSeleccionada == null || equipo.area == areaSeleccionada;
          final coincideEstado =
              estadoSeleccionado == null || equipo.estado == estadoSeleccionado;

          return coincideBusqueda && coincideArea && coincideEstado;
        }).toList();
      });
    });

// Leandro: Desde aquí continúan los providers anteriores de Áreas y del detalle.
// Listado consolidado de todos los equipos
final equiposResumenProvider = FutureProvider<List<ResumenEquipoViewModel>>((
  ref,
) async {
  final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
  final query = ref.watch(busquedaEquipoProvider).toLowerCase();

  final agrupado = <String, List<CumplimientoEmpleado>>{};
  for (final item in cumplimientos) {
    agrupado.putIfAbsent(item.empleado.area, () => []).add(item);
  }

  final lista = <ResumenEquipoViewModel>[];

  agrupado.forEach((area, miembros) {
    final totalIntegrantes = miembros.length;
    final integrantesCumplen = miembros.where((m) => m.cumpleObjetivo).length;
    final horasRealizadas = miembros.fold<double>(
      0.0,
      (acc, item) => acc + item.totalHorasCompletadas,
    );
    final horasRequeridas = miembros.fold<double>(
      0.0,
      (acc, item) => acc + item.totalHorasRequeridas,
    );

    final porcentaje = horasRequeridas == 0
        ? 100.0
        : (horasRealizadas / horasRequeridas) * 100;
    final equiposGenerales =
        miembros
            .map((miembro) => miembro.empleado.equipo.trim())
            .where((equipo) => equipo.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    lista.add(
      ResumenEquipoViewModel(
        nombreArea: area,
        cantidadIntegrantes: totalIntegrantes,
        integrantesCumplen: integrantesCumplen,
        horasTotalesRealizadas: horasRealizadas,
        horasTotalesRequeridas: horasRequeridas,
        porcentajeCumplimiento: porcentaje,
        semaforo: EstadoSemaforo.desdePorcentaje(porcentaje),
        equiposGenerales: equiposGenerales,
      ),
    );
  });

  return lista
      .where(
        (area) =>
            area.nombreArea.toLowerCase().contains(query) ||
            area.equiposGenerales.any(
              (equipo) => equipo.toLowerCase().contains(query),
            ),
      )
      .toList();
});

// Detalle de un equipo particular por su nombre/área
final detalleEquipoProvider =
    FutureProvider.family<DetalleEquipoViewModel, String>((
      ref,
      nombreArea,
    ) async {
      final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
      final areas = await ref.watch(equiposResumenProvider.future);

      final resumen = areas.firstWhere(
        (e) => e.nombreArea.toLowerCase() == nombreArea.toLowerCase(),
        orElse: () => throw Exception('Equipo no encontrado'),
      );

      final miembros = cumplimientos
          .where(
            (c) => c.empleado.area.toLowerCase() == nombreArea.toLowerCase(),
          )
          .toList();
      final miembrosPorEquipo = <String, List<CumplimientoEmpleado>>{};
      for (final miembro in miembros) {
        final equipo = miembro.empleado.equipo.trim().isEmpty
            ? 'Sin equipo asignado'
            : miembro.empleado.equipo.trim();
        miembrosPorEquipo.putIfAbsent(equipo, () => []).add(miembro);
      }

      return DetalleEquipoViewModel(
        nombreArea: resumen.nombreArea,
        resumen: resumen,
        miembros: miembros,
        miembrosPorEquipo: miembrosPorEquipo,
      );
    });

final detalleEquipoGeneralProvider =
    FutureProvider.family<
      DetalleEquipoGeneralViewModel,
      ({String area, String equipo})
    >((ref, params) async {
      final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
      final miembros = cumplimientos.where((cumplimiento) {
        return cumplimiento.empleado.area.toLowerCase() ==
                params.area.toLowerCase() &&
            cumplimiento.empleado.equipo.toLowerCase() ==
                params.equipo.toLowerCase();
      }).toList();

      if (miembros.isEmpty) {
        throw Exception('Equipo general no encontrado');
      }

      return DetalleEquipoGeneralViewModel(
        nombreArea: params.area,
        nombreEquipo: params.equipo,
        miembros: miembros,
      );
    });
