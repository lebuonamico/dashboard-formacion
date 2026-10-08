import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:app_finnegans/domain/servicios/teams_service.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/period_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

export 'package:app_finnegans/domain/modelos/team_overview.dart';
export 'package:app_finnegans/domain/modelos/team_status.dart';
export 'package:app_finnegans/presentation/providers/period_providers.dart';

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

final busquedaEquipoProvider = StateProvider<String>((ref) => '');
final filtroAreaEquipoProvider = StateProvider<String?>((ref) => null);
final filtroEstadoEquipoProvider = StateProvider<EstadoEquipo?>((ref) => null);

final equiposServiceProvider = Provider<EquiposService>((ref) {
  // Leandro: llama a EquiposService para disponer de los cálculos compartidos por resumen y detalle.
  return EquiposService();
});

final aniosEquipoDisponiblesProvider = FutureProvider<List<int>>((ref) async {
  final cargasDeHoras = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  final anios = cargasDeHoras.map((carga) => carga.fecha.year).toSet()
    ..addAll(
      certificaciones
          .map((certificacion) => certificacion.fechaFinalizacion?.year)
          .whereType<int>(),
    )
    ..add(DateTime.now().year);
  final lista = anios.toList()..sort((a, b) => b.compareTo(a));

  return lista;
});

final hayDatosEquiposPeriodoProvider = FutureProvider<bool>((ref) async {
  final alcance = ref.watch(alcancePeriodoProvider);
  final mes = ref.watch(filtroMesPeriodoProvider);
  final anio = ref.watch(filtroAnioPeriodoProvider);
  final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  // Leandro: llama a tieneDatosEnPeriodo para comprobar si existen registros CRM o LMS en el período elegido.
  return ref
      .read(equiposServiceProvider)
      .tieneDatosEnPeriodo(
        cargas: cargas,
        certificaciones: certificaciones,
        anio: anio,
        mes: mes,
        esAnual: alcance == AlcancePeriodo.anual,
      );
});

final cumplimientoEquiposProvider = FutureProvider<List<CumplimientoEmpleado>>((
  ref,
) async {
  // Leandro: llama a hayDatosEquiposPeriodoProvider para evitar evaluar colaboradores cuando no hay datos del período.
  if (!await ref.watch(hayDatosEquiposPeriodoProvider.future)) return [];

  final empleados = await ref.watch(empleadosProvider.future);
  final historial = await ref.watch(empleadoHistorialProvider.future);
  final cursos = await ref.watch(cursosProvider.future);
  final cargasDeHoras = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  final alcance = ref.watch(alcancePeriodoProvider);
  final mes = ref.watch(filtroMesPeriodoProvider);
  final anio = ref.watch(filtroAnioPeriodoProvider);
  final cumplimientoService = ref.read(cumplimientoServiceProvider);
  final equiposService = ref.read(equiposServiceProvider);

  if (alcance == AlcancePeriodo.anual) {
    // Leandro: llama a calcularCumplimientoAnual para sumar los resultados mensuales de los períodos con datos.
    return equiposService.calcularCumplimientoAnual(
      empleados: empleados,
      historial: historial,
      cursos: cursos,
      cargas: cargasDeHoras,
      certificaciones: certificaciones,
      anio: anio,
      cumplimientoService: cumplimientoService,
    );
  }

  // Leandro: llama a filtrarCargasPorPeriodo para seleccionar las horas CRM del mes elegido.
  final cargasFiltradas = equiposService.filtrarCargasPorPeriodo(
    cargas: cargasDeHoras,
    anio: anio,
    mes: mes,
    esAnual: alcance == AlcancePeriodo.anual,
  );
  // Leandro: llama a filtrarCertificacionesPorPeriodo para seleccionar las finalizaciones LMS del período.
  final certificacionesFiltradas = equiposService
      .filtrarCertificacionesPorPeriodo(
        certificaciones: certificaciones,
        anio: anio,
        mes: mes,
        esAnual: alcance == AlcancePeriodo.anual,
      );
  // Leandro: llama a filtrarEmpleadosPorPeriodo para incluir los ingresos y estados activos vigentes al cierre del mes.
  final empleadosElegibles = equiposService.filtrarEmpleadosPorPeriodo(
    empleados: empleados,
    historial: historial,
    anio: anio,
    mes: mes,
    esAnual: alcance == AlcancePeriodo.anual,
  );

  // Leandro: llama a calcularCumplimientoGlobal para obtener las horas válidas y los objetivos de los colaboradores elegibles.
  final cumplimientos = cumplimientoService.calcularCumplimientoGlobal(
    empleados: empleadosElegibles,
    cursos: cursos,
    cargasDeHoras: cargasFiltradas,
    certificacionesMoodle: certificacionesFiltradas,
  );

  return cumplimientos;
});

final resumenEquiposPeriodoProvider = FutureProvider<ResumenEquiposPeriodo>((
  ref,
) async {
  if (!await ref.watch(hayDatosEquiposPeriodoProvider.future)) {
    // Leandro: llama a ResumenEquiposPeriodo.sinDatos para representar un período que todavía no fue evaluado.
    return const ResumenEquiposPeriodo.sinDatos();
  }
  final cumplimientos = await ref.watch(cumplimientoEquiposProvider.future);
  final equiposService = ref.read(equiposServiceProvider);
  // Leandro: llama a toSet para contar una sola vez cada legajo elegible en los meses con datos del año.
  final colaboradoresUnicosAnuales =
      ref.watch(alcancePeriodoProvider) == AlcancePeriodo.anual
      ? cumplimientos.map((item) => item.empleado.legajo).toSet().length
      : null;
  // Leandro: llama a calcularResumenPeriodo para obtener los indicadores y estados de todos los equipos elegibles.
  return equiposService.calcularResumenPeriodo(
    cumplimientos,
    colaboradoresAlCierre: colaboradoresUnicosAnuales,
  );
});

// Conserva el contrato usado por Dashboard y por el detalle de Áreas.
final equiposGlobalProvider = FutureProvider<List<EquipoGlobalViewModel>>((
  ref,
) async {
  final resumen = await ref.watch(resumenEquiposPeriodoProvider.future);
  return resumen.equipos;
});

final equiposGlobalFiltradosProvider =
    Provider<AsyncValue<List<EquipoGlobalViewModel>>>((ref) {
      final areaSeleccionada = ref.watch(filtroAreaEquipoProvider);
      final estadoSeleccionado = ref.watch(filtroEstadoEquipoProvider);
      final resumenAsync = ref.watch(resumenEquiposPeriodoProvider);
      final query = ref.watch(busquedaEquipoProvider).trim().toLowerCase();

      // Leandro: llama a AsyncValue.whenData para aplicar los filtros sólo cuando el resumen está disponible.
      return resumenAsync.whenData((resumen) {
        return resumen.equipos.where((equipo) {
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

ResumenEquipoViewModel _resumirArea(
  String area,
  List<CumplimientoEmpleado> miembros,
) {
  final legajos = miembros.map((m) => m.empleado.legajo).toSet();
  final legajosPendientes = miembros
      .where((m) => !m.cumpleObjetivo)
      .map((m) => m.empleado.legajo)
      .toSet();
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

  return ResumenEquipoViewModel(
    nombreArea: area,
    cantidadIntegrantes: legajos.length,
    integrantesCumplen: legajos.difference(legajosPendientes).length,
    horasTotalesRealizadas: horasRealizadas,
    horasTotalesRequeridas: horasRequeridas,
    porcentajeCumplimiento: porcentaje,
    semaforo: EstadoSemaforo.desdePorcentaje(porcentaje),
    equiposGenerales: equiposGenerales,
  );
}

final equiposResumenProvider = FutureProvider<List<ResumenEquipoViewModel>>((
  ref,
) async {
  final cumplimientos = await ref.watch(cumplimientoEquiposProvider.future);
  final query = ref.watch(busquedaEquipoProvider).toLowerCase();

  final agrupado = <String, List<CumplimientoEmpleado>>{};
  for (final item in cumplimientos) {
    agrupado.putIfAbsent(item.empleado.area, () => []).add(item);
  }

  final lista = [
    for (final entry in agrupado.entries) _resumirArea(entry.key, entry.value),
  ];

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
    FutureProvider.family<DetalleEquipoViewModel?, String>((
      ref,
      nombreArea,
    ) async {
      final cumplimientos = await ref.watch(cumplimientoEquiposProvider.future);

      final miembros = cumplimientos
          .where(
            (c) => c.empleado.area.toLowerCase() == nombreArea.toLowerCase(),
          )
          .toList();
      if (miembros.isEmpty) return null;
      final resumen = _resumirArea(miembros.first.empleado.area, miembros);
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
      DetalleEquipoGeneral?,
      ({String area, String equipo})
    >((ref, params) async {
      final cumplimientos = await ref.watch(cumplimientoEquiposProvider.future);
      final equiposService = ref.read(equiposServiceProvider);
      // Leandro: llama a obtenerDetalleEquipo para recuperar los integrantes y el resumen del equipo solicitado.
      return equiposService.obtenerDetalleEquipo(
        cumplimientos: cumplimientos,
        area: params.area,
        equipo: params.equipo,
      );
    });
