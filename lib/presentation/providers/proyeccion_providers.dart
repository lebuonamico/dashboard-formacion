import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/domain/servicios/proyeccion_service.dart';

/// Mes en el que se corta la proyección: el elegido en el mensual; en el
/// anual, el último mes del año con datos. `null` si el año no tiene datos.
final mesCorteProyeccionAnualProvider = FutureProvider<int?>((ref) async {
  final anio = ref.watch(filtroAnioPeriodoProvider);
  if (ref.watch(alcancePeriodoProvider) == AlcancePeriodo.mensual) {
    return ref.watch(filtroMesPeriodoProvider);
  }
  final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  return ref
      .read(equiposServiceProvider)
      .periods
      .lastMonthWithData(
        timeEntries: cargas,
        certifications: certificaciones,
        year: anio,
      );
});

/// Cumplimiento de cada mes con datos de enero al mes de corte, con la misma
/// nómina elegible y alcance del usuario que Equipos y Áreas. Lo comparten
/// todas las secciones; cada una filtra sus colaboradores.
final cumplimientoPorMesProvider =
    FutureProvider<Map<int, List<CumplimientoEmpleado>>>((ref) async {
      final mesCorte = await ref.watch(mesCorteProyeccionAnualProvider.future);
      if (mesCorte == null) return {};

      final anio = ref.watch(filtroAnioPeriodoProvider);
      final empleados = await ref.watch(empleadosProvider.future);
      final historial = await ref.watch(empleadoHistorialProvider.future);
      final cursos = await ref.watch(cursosProvider.future);
      final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
      final certificaciones = await ref.watch(
        certificacionesMoodleProvider.future,
      );
      final cumplimientoService = await ref.watch(
        cumplimientoServiceProvider.future,
      );
      final alcanceUsuario = await ref.watch(alcanceUsuarioProvider.future);
      final incluir = alcanceUsuario.esTotal
          ? null
          : alcanceUsuario.incluyeEmpleado;
      final equiposService = ref.read(equiposServiceProvider);

      return equiposService.periods.calculateComplianceByMonth(
        employees: empleados,
        history: historial,
        courses: cursos,
        timeEntries: cargas,
        certifications: certificaciones,
        year: anio,
        throughMonth: mesCorte,
        complianceService: cumplimientoService,
        includeEmployee: incluir,
      );
    });

/// Cuánto cambió el cumplimiento de una sección contra el mes anterior.
class VariacionCumplimiento {
  /// Anual: puntos que subió o bajó el acumulado del año contra el acumulado
  /// hasta el mes con datos anterior. `null` si no hay mes anterior.
  final double? puntos;

  /// Mensual: horas por persona del mes de corte, con el tope mensual.
  final double horasPersona;

  /// Horas por persona del mes anterior; `null` si ese mes no tiene datos.
  final double? horasPersonaAnterior;

  const VariacionCumplimiento({
    required this.puntos,
    required this.horasPersona,
    required this.horasPersonaAnterior,
  });

  double? get horas => horasPersonaAnterior == null
      ? null
      : horasPersona - horasPersonaAnterior!;
}

/// Variación del cumplimiento de una sección: `(area: null, equipo: null)` es
/// toda la nómina visible. Cada mes se filtra con dónde estaba cada
/// colaborador ese mes, igual que el cumplimiento de Áreas y Equipos, y se
/// acumula con el mismo cálculo que el anual.
final variacionCumplimientoProvider =
    FutureProvider.family<
      VariacionCumplimiento?,
      ({String? area, String? equipo})
    >((ref, seccion) async {
      final mesCorte = await ref.watch(mesCorteProyeccionAnualProvider.future);
      if (mesCorte == null) return null;
      final porMes = await ref.watch(cumplimientoPorMesProvider.future);
      final equiposService = ref.read(equiposServiceProvider);

      final todos = seccion.area == null && seccion.equipo == null;
      final filtrado = {
        for (final entry in porMes.entries)
          entry.key: todos
              ? entry.value
              : entry.value
                    .where(
                      (item) => equiposService.periods.belongsToTeam(
                        item.empleado,
                        area: seccion.area,
                        team: seccion.equipo,
                      ),
                    )
                    .toList(),
      };

      double porcentaje(int hasta) {
        final acumulado = equiposService.periods.accumulateMonths([
          for (final entry in filtrado.entries)
            if (entry.key <= hasta) entry.value,
        ]);
        final horas = acumulado.fold<double>(
          0,
          (t, c) => t + c.totalHorasCompletadas,
        );
        final objetivo = acumulado.fold<double>(
          0,
          (t, c) => t + c.totalHorasRequeridas,
        );
        return objetivo == 0 ? 0 : horas / objetivo * 100;
      }

      double? horasPersona(int mes) {
        final items = filtrado[mes];
        if (items == null || items.isEmpty) return null;
        return items.fold<double>(0, (t, c) => t + c.totalHorasCompletadas) /
            items.length;
      }

      final actual = horasPersona(mesCorte);
      if (actual == null) return null;
      final anteriores =
          filtrado.entries
              .where((e) => e.key < mesCorte && e.value.isNotEmpty)
              .map((e) => e.key)
              .toList()
            ..sort();
      return VariacionCumplimiento(
        puntos: anteriores.isEmpty
            ? null
            : porcentaje(mesCorte) - porcentaje(anteriores.last),
        horasPersona: actual,
        horasPersonaAnterior: horasPersona(mesCorte - 1),
      );
    });

/// Proyección de un colaborador por categoría, para su pantalla de detalle.
/// `null` si no está en la nómina elegible del mes de corte.
final proyeccionEmpleadoProvider =
    FutureProvider.family<ProyeccionEmpleado?, String>((ref, legajo) async {
      final mesCorte = await ref.watch(mesCorteProyeccionAnualProvider.future);
      if (mesCorte == null) return null;
      final porMes = await ref.watch(cumplimientoPorMesProvider.future);
      final propio = {
        for (final entry in porMes.entries)
          entry.key: entry.value
              .where((item) => item.empleado.legajo == legajo)
              .toList(),
      };
      const service = ProyeccionService();
      final actual = service
          .proyectarEmpleados(porMes: propio, mesCorte: mesCorte)
          .firstOrNull;
      if (actual == null) return null;

      // La misma proyección cortada en el mes anterior en el que estuvo.
      final anteriores =
          propio.entries
              .where((e) => e.key < mesCorte && e.value.isNotEmpty)
              .map((e) => e.key)
              .toList()
            ..sort();
      if (anteriores.isEmpty) return actual;
      final previa = service
          .proyectarEmpleados(porMes: propio, mesCorte: anteriores.last)
          .firstOrNull;
      return ProyeccionEmpleado(
        legajo: actual.legajo,
        mesCorte: actual.mesCorte,
        categorias: actual.categorias,
        porcentajeAnterior: previa?.porcentaje,
      );
    });

/// Proyección de una sección: `(area: null, equipo: null)` es toda la nómina
/// visible; con área, solo esa área; con área y equipo, solo ese equipo.
final proyeccionAnualProvider =
    FutureProvider.family<ProyeccionAnual?, ({String? area, String? equipo})>((
      ref,
      seccion,
    ) async {
      final mesCorte = await ref.watch(mesCorteProyeccionAnualProvider.future);
      if (mesCorte == null) return null;
      final porMes = await ref.watch(cumplimientoPorMesProvider.future);
      final equiposService = ref.read(equiposServiceProvider);

      // La sección se define por dónde está cada colaborador en el mes de
      // corte; de ellos se toma todo el historial del año, aunque antes
      // estuvieran en otro equipo.
      Map<int, List<CumplimientoEmpleado>> filtrado = porMes;
      if (seccion.area != null || seccion.equipo != null) {
        final legajos = {
          for (final item in porMes[mesCorte] ?? const <CumplimientoEmpleado>[])
            if (equiposService.periods.belongsToTeam(
              item.empleado,
              area: seccion.area,
              team: seccion.equipo,
            ))
              item.empleado.legajo,
        };
        filtrado = {
          for (final entry in porMes.entries)
            entry.key: entry.value
                .where((item) => legajos.contains(item.empleado.legajo))
                .toList(),
        };
      }
      return const ProyeccionService().calcular(
        porMes: filtrado,
        mesCorte: mesCorte,
      );
    });
