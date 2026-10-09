import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';

/// Resumen de un área en el período, para las tarjetas de la pantalla Áreas.
class AreaGlobalViewModel {
  final String nombre;
  final List<String> equiposGenerales;
  final int cantidadIntegrantes;
  final int integrantesEnObjetivo;
  final double horasRealizadas;
  final double horasObjetivo;
  final double horasNegocio;
  final double horasBlandas;
  final double horasLibres;
  final double horasDictado;
  final double porcentajeCumplimiento;

  /// El estado del área sólo mira el porcentaje de horas, igual que el
  /// Dashboard. No exige que todos los integrantes cumplan, como en Equipos.
  final EstadoSemaforo semaforo;

  const AreaGlobalViewModel({
    required this.nombre,
    required this.equiposGenerales,
    required this.cantidadIntegrantes,
    required this.integrantesEnObjetivo,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.horasNegocio,
    required this.horasBlandas,
    required this.horasLibres,
    required this.horasDictado,
    required this.porcentajeCumplimiento,
    required this.semaforo,
  });

  double get desvioHoras => horasRealizadas - horasObjetivo;
}

/// Totales del período que consume la pantalla de Áreas.
class ResumenAreasPeriodo {
  final bool tieneDatos;
  final List<AreaGlobalViewModel> areas;
  final int colaboradores;
  final double horasRealizadas;
  final double horasObjetivo;
  final double horasNegocio;
  final double horasBlandas;
  final double horasLibres;
  final double horasDictado;
  final int enObjetivo;
  final int enRiesgo;
  final int criticos;

  const ResumenAreasPeriodo({
    this.tieneDatos = true,
    required this.areas,
    required this.colaboradores,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.horasNegocio,
    required this.horasBlandas,
    required this.horasLibres,
    required this.horasDictado,
    required this.enObjetivo,
    required this.enRiesgo,
    required this.criticos,
  });

  const ResumenAreasPeriodo.sinDatos()
    : this(
        tieneDatos: false,
        areas: const [],
        colaboradores: 0,
        horasRealizadas: 0,
        horasObjetivo: 0,
        horasNegocio: 0,
        horasBlandas: 0,
        horasLibres: 0,
        horasDictado: 0,
        enObjetivo: 0,
        enRiesgo: 0,
        criticos: 0,
      );

  int get totalAreas => areas.length;
  double get desvioHoras => horasRealizadas - horasObjetivo;
  double get cumplimientoGlobal =>
      horasObjetivo == 0 ? 0 : horasRealizadas / horasObjetivo * 100;
}

// Filtros propios de Áreas: buscar acá no filtra la pantalla de Equipos.
final busquedaAreaProvider = StateProvider<String>((ref) => '');
final filtroEstadoAreaProvider = StateProvider<EstadoSemaforo?>((ref) => null);

final resumenAreasPeriodoProvider = FutureProvider<ResumenAreasPeriodo>((
  ref,
) async {
  if (!await ref.watch(hayDatosEquiposPeriodoProvider.future)) {
    return const ResumenAreasPeriodo.sinDatos();
  }
  // Mismo cálculo que Equipos: el período global y la nómina elegible.
  final cumplimientos = await ref.watch(cumplimientoEquiposProvider.future);

  final agrupado = <String, List<CumplimientoEmpleado>>{};
  for (final item in cumplimientos) {
    agrupado.putIfAbsent(item.empleado.area, () => []).add(item);
  }

  final areas = [
    for (final entry in agrupado.entries) _resumirArea(entry.key, entry.value),
  ]..sort(_compararAreasPorPrioridad);

  var horasRealizadas = 0.0;
  var horasObjetivo = 0.0;
  var horasNegocio = 0.0;
  var horasBlandas = 0.0;
  var horasLibres = 0.0;
  var horasDictado = 0.0;
  for (final area in areas) {
    horasRealizadas += area.horasRealizadas;
    horasObjetivo += area.horasObjetivo;
    horasNegocio += area.horasNegocio;
    horasBlandas += area.horasBlandas;
    horasLibres += area.horasLibres;
    horasDictado += area.horasDictado;
  }

  return ResumenAreasPeriodo(
    areas: areas,
    // En el anual un legajo puede aparecer una vez por equipo: se cuenta una
    // sola vez.
    colaboradores: cumplimientos
        .map((item) => item.empleado.legajo)
        .toSet()
        .length,
    horasRealizadas: horasRealizadas,
    horasObjetivo: horasObjetivo,
    horasNegocio: horasNegocio,
    horasBlandas: horasBlandas,
    horasLibres: horasLibres,
    horasDictado: horasDictado,
    enObjetivo: areas.where((a) => a.semaforo == EstadoSemaforo.verde).length,
    enRiesgo: areas.where((a) => a.semaforo == EstadoSemaforo.amarillo).length,
    criticos: areas.where((a) => a.semaforo == EstadoSemaforo.rojo).length,
  );
});

final areasFiltradasProvider = Provider<AsyncValue<List<AreaGlobalViewModel>>>((
  ref,
) {
  final resumenAsync = ref.watch(resumenAreasPeriodoProvider);
  final query = ref.watch(busquedaAreaProvider).trim().toLowerCase();
  final estado = ref.watch(filtroEstadoAreaProvider);

  return resumenAsync.whenData((resumen) {
    return resumen.areas.where((area) {
      final coincideBusqueda =
          query.isEmpty ||
          area.nombre.toLowerCase().contains(query) ||
          area.equiposGenerales.any(
            (equipo) => equipo.toLowerCase().contains(query),
          );
      final coincideEstado = estado == null || area.semaforo == estado;

      return coincideBusqueda && coincideEstado;
    }).toList();
  });
});

/// Área seleccionada junto con sus equipos y los integrantes evaluados en el
/// período.
class DetalleAreaViewModel {
  final AreaGlobalViewModel area;
  final List<EquipoGlobalViewModel> equipos;
  final List<CumplimientoEmpleado> miembros;

  const DetalleAreaViewModel({
    required this.area,
    required this.equipos,
    required this.miembros,
  });
}

/// Chips de la tabla de integrantes del detalle: `cumplido`, `riesgo`,
/// `critico` o null (todos). Se descarta al salir de la pantalla.
final filtroEstadoMiembroAreaProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final detalleAreaProvider =
    FutureProvider.family<DetalleAreaViewModel?, String>((
      ref,
      nombreArea,
    ) async {
      final cumplimientos = await ref.watch(cumplimientoEquiposProvider.future);
      final buscada = nombreArea.trim().toLowerCase();

      final miembros =
          cumplimientos
              .where(
                (item) => item.empleado.area.trim().toLowerCase() == buscada,
              )
              .toList()
            ..sort(
              (a, b) => a.empleado.nombreCompleto.compareTo(
                b.empleado.nombreCompleto,
              ),
            );
      if (miembros.isEmpty) return null;

      // Los equipos salen del mismo cálculo que la pantalla de Equipos, así
      // las tarjetas muestran los mismos números en las dos pantallas.
      final resumenEquipos = await ref.watch(
        resumenEquiposPeriodoProvider.future,
      );
      final equipos = resumenEquipos.equipos
          .where((equipo) => equipo.area.trim().toLowerCase() == buscada)
          .toList();

      return DetalleAreaViewModel(
        area: _resumirArea(miembros.first.empleado.area, miembros),
        equipos: equipos,
        miembros: miembros,
      );
    });

AreaGlobalViewModel _resumirArea(
  String area,
  List<CumplimientoEmpleado> miembros,
) {
  final legajos = miembros.map((m) => m.empleado.legajo).toSet();
  // Un legajo con alguna entrada pendiente no cuenta como en objetivo.
  final legajosPendientes = miembros
      .where((m) => !m.cumpleObjetivo)
      .map((m) => m.empleado.legajo)
      .toSet();
  final horasRealizadas = miembros.fold<double>(
    0,
    (total, item) => total + item.totalHorasCompletadas,
  );
  final horasObjetivo = miembros.fold<double>(
    0,
    (total, item) => total + item.totalHorasRequeridas,
  );
  final porcentaje = horasObjetivo == 0
      ? 100.0
      : (horasRealizadas / horasObjetivo) * 100;
  final equiposGenerales =
      miembros
          .map((miembro) => miembro.empleado.equipo.trim())
          .where((equipo) => equipo.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  return AreaGlobalViewModel(
    nombre: area,
    equiposGenerales: equiposGenerales,
    cantidadIntegrantes: legajos.length,
    integrantesEnObjetivo: legajos.difference(legajosPendientes).length,
    horasRealizadas: horasRealizadas,
    horasObjetivo: horasObjetivo,
    horasNegocio: _sumarHorasCategoria(
      miembros,
      TipoCurso.habilidadesDeNegocio,
    ),
    horasBlandas: _sumarHorasCategoria(miembros, TipoCurso.habilidadesBlandas),
    horasLibres: _sumarHorasCategoria(miembros, TipoCurso.libresExploracion),
    horasDictado: _sumarHorasCategoria(
      miembros,
      TipoCurso.dictadoCapacitaciones,
    ),
    porcentajeCumplimiento: porcentaje,
    semaforo: EstadoSemaforo.desdePorcentaje(porcentaje),
  );
}

double _sumarHorasCategoria(
  List<CumplimientoEmpleado> miembros,
  TipoCurso tipo,
) {
  return miembros.fold<double>(
    0,
    (total, miembro) => total + miembro.horasAplicablesAlObjetivo(tipo),
  );
}

/// Lo que peor está, primero: críticas, en riesgo y en objetivo; dentro de
/// cada estado por porcentaje ascendente y después por nombre.
int _compararAreasPorPrioridad(AreaGlobalViewModel a, AreaGlobalViewModel b) {
  final estado = _ordenSemaforo(
    a.semaforo,
  ).compareTo(_ordenSemaforo(b.semaforo));
  if (estado != 0) return estado;

  final cumplimiento = a.porcentajeCumplimiento.compareTo(
    b.porcentajeCumplimiento,
  );
  if (cumplimiento != 0) return cumplimiento;

  return a.nombre.compareTo(b.nombre);
}

int _ordenSemaforo(EstadoSemaforo semaforo) {
  switch (semaforo) {
    case EstadoSemaforo.rojo:
      return 0;
    case EstadoSemaforo.amarillo:
      return 1;
    case EstadoSemaforo.verde:
      return 2;
  }
}
