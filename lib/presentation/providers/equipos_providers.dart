import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
//import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

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

// Filtro de búsqueda para la lista de equipos
final busquedaEquipoProvider = StateProvider<String>((ref) => '');

// Listado consolidado de todos los equipos
final equiposResumenProvider =
    FutureProvider<List<ResumenEquipoViewModel>>((ref) async {
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
        0.0, (acc, item) => acc + item.totalHorasCompletadas);
    final horasRequeridas = miembros.fold<double>(
        0.0, (acc, item) => acc + item.totalHorasRequeridas);

    final porcentaje = horasRequeridas == 0
        ? 100.0
        : (horasRealizadas / horasRequeridas) * 100;
    final equiposGenerales = miembros
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
        .where((area) => area.nombreArea.toLowerCase().contains(query) ||
          area.equiposGenerales.any((equipo) => equipo.toLowerCase().contains(query)))
      .toList();
});

// Detalle de un equipo particular por su nombre/área
final detalleEquipoProvider =
    FutureProvider.family<DetalleEquipoViewModel, String>((ref, nombreArea) async {
  final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
  final areas = await ref.watch(equiposResumenProvider.future);

  final resumen = areas.firstWhere(
    (e) => e.nombreArea.toLowerCase() == nombreArea.toLowerCase(),
    orElse: () => throw Exception('Equipo no encontrado'),
  );

  final miembros = cumplimientos
      .where((c) => c.empleado.area.toLowerCase() == nombreArea.toLowerCase())
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
    FutureProvider.family<DetalleEquipoGeneralViewModel, ({String area, String equipo})>((ref, params) async {
  final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
  final miembros = cumplimientos.where((cumplimiento) {
    return cumplimiento.empleado.area.toLowerCase() == params.area.toLowerCase() &&
        cumplimiento.empleado.equipo.toLowerCase() == params.equipo.toLowerCase();
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