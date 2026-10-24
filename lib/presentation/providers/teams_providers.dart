import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
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
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/providers/period_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

export 'package:app_finnegans/domain/modelos/team_overview.dart';
export 'package:app_finnegans/domain/modelos/team_status.dart';
export 'package:app_finnegans/presentation/providers/period_providers.dart';

final busquedaEquipoProvider = StateProvider<String>((ref) => '');
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
  final cumplimientoService = await ref.watch(
    cumplimientoServiceProvider.future,
  );
  final equiposService = ref.read(equiposServiceProvider);
  // El alcance se vuelve a aplicar sobre el equipo vigente en cada mes: un
  // líder no ve los meses en que la persona estaba en otro equipo.
  final alcanceUsuario = await ref.watch(alcanceUsuarioProvider.future);
  final incluir = alcanceUsuario.esTotal
      ? null
      : alcanceUsuario.incluyeEmpleado;

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
      incluir: incluir,
    );
  }

  // Leandro: llama a calcularCumplimientoMensual para obtener las horas válidas y los objetivos de los colaboradores elegibles del mes.
  return equiposService.calcularCumplimientoMensual(
    empleados: empleados,
    historial: historial,
    cursos: cursos,
    cargas: cargasDeHoras,
    certificaciones: certificaciones,
    anio: anio,
    mes: mes,
    cumplimientoService: cumplimientoService,
    incluir: incluir,
  );
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
  final lideres = await ref.watch(etiquetasLideresProvider.future);
  // Leandro: llama a toSet para contar una sola vez cada legajo elegible en los meses con datos del año.
  final colaboradoresUnicosAnuales =
      ref.watch(alcancePeriodoProvider) == AlcancePeriodo.anual
      ? cumplimientos.map((item) => item.empleado.legajo).toSet().length
      : null;
  // Leandro: llama a calcularResumenPeriodo para obtener los indicadores y estados de todos los equipos elegibles.
  return equiposService.calcularResumenPeriodo(
    cumplimientos,
    colaboradoresAlCierre: colaboradoresUnicosAnuales,
    liderDe: lideres?.deEquipo,
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
      final estadoSeleccionado = ref.watch(filtroEstadoEquipoProvider);
      final selection = ref.watch(dataFilterSelectionProvider('equipos'));
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

          final coincideEstado =
              estadoSeleccionado == null || equipo.estado == estadoSeleccionado;

          return coincideBusqueda &&
              coincideEstado &&
              matchesDataFilters(selection, equipoFilterRow(equipo));
        }).toList();
      });
    });

final detalleEquipoGeneralProvider =
    FutureProvider.family<
      DetalleEquipoGeneral?,
      ({String area, String equipo})
    >((ref, params) async {
      final cumplimientos = await ref.watch(cumplimientoEquiposProvider.future);
      final equiposService = ref.read(equiposServiceProvider);
      final lideres = await ref.watch(etiquetasLideresProvider.future);
      // Leandro: llama a obtenerDetalleEquipo para recuperar los integrantes y el resumen del equipo solicitado.
      return equiposService.obtenerDetalleEquipo(
        cumplimientos: cumplimientos,
        area: params.area,
        equipo: params.equipo,
        liderDe: lideres?.deEquipo,
      );
    });
