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

  ResumenEquipoViewModel({
    required this.nombreArea,
    required this.cantidadIntegrantes,
    required this.integrantesCumplen,
    required this.horasTotalesRealizadas,
    required this.horasTotalesRequeridas,
    required this.porcentajeCumplimiento,
    required this.semaforo,
  });
}

class DetalleEquipoViewModel {
  final String nombreArea;
  final ResumenEquipoViewModel resumen;
  final List<CumplimientoEmpleado> miembros;

  DetalleEquipoViewModel({
    required this.nombreArea,
    required this.resumen,
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

    lista.add(
      ResumenEquipoViewModel(
        nombreArea: area,
        cantidadIntegrantes: totalIntegrantes,
        integrantesCumplen: integrantesCumplen,
        horasTotalesRealizadas: horasRealizadas,
        horasTotalesRequeridas: horasRequeridas,
        porcentajeCumplimiento: porcentaje,
        semaforo: EstadoSemaforo.desdePorcentaje(porcentaje),
      ),
    );
  });

  return lista
      .where((eq) => eq.nombreArea.toLowerCase().contains(query))
      .toList();
});

// Detalle de un equipo particular por su nombre/área
final detalleEquipoProvider =
    FutureProvider.family<DetalleEquipoViewModel, String>((ref, nombreArea) async {
  final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
  final equipos = await ref.watch(equiposResumenProvider.future);

  final resumen = equipos.firstWhere(
    (e) => e.nombreArea.toLowerCase() == nombreArea.toLowerCase(),
    orElse: () => throw Exception('Equipo no encontrado'),
  );

  final miembros = cumplimientos
      .where((c) => c.empleado.area.toLowerCase() == nombreArea.toLowerCase())
      .toList();

  return DetalleEquipoViewModel(
    nombreArea: resumen.nombreArea,
    resumen: resumen,
    miembros: miembros,
  );
});