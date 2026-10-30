import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';

/// Los colores de cada estado los resuelve la UI según el tema activo
/// (ver `widgets/shared/estado_colores.dart`).
enum EstadoSemaforo {
  verde('En objetivo'),
  amarillo('En riesgo'),
  rojo('Crítico');

  final String label;

  const EstadoSemaforo(this.label);

  static EstadoSemaforo desdePorcentaje(double porcentaje) {
    if (porcentaje >= 100.0) return EstadoSemaforo.verde;
    if (porcentaje >= 70.0) return EstadoSemaforo.amarillo;
    return EstadoSemaforo.rojo;
  }
}

class SemaforoAreaViewModel {
  final String area;
  final int cantidadColaboradores;
  final double horasCompletadas;
  final double horasRequeridas;
  final double porcentajeCumplimiento;
  final EstadoSemaforo semaforo;

  SemaforoAreaViewModel({
    required this.area,
    required this.cantidadColaboradores,
    required this.horasCompletadas,
    required this.horasRequeridas,
    required this.porcentajeCumplimiento,
    required this.semaforo,
  });
}

final semaforoPorAreaProvider = FutureProvider<List<SemaforoAreaViewModel>>((
  ref,
) async {
  final cumplimientos = await ref.watch(cumplimientoDashboardProvider.future);

  final agrupadoPorArea = <String, List<CumplimientoEmpleado>>{};
  for (final item in cumplimientos) {
    agrupadoPorArea.putIfAbsent(item.empleado.area, () => []).add(item);
  }

  final resultado = <SemaforoAreaViewModel>[];

  agrupadoPorArea.forEach((area, listaItems) {
    final horasCompletadas = listaItems.fold<double>(
      0.0,
      (acc, item) => acc + item.totalHorasValidas,
    );
    final horasRequeridas = listaItems.fold<double>(
      0.0,
      (acc, item) => acc + item.totalHorasRequeridas,
    );

    final porcentaje = horasRequeridas == 0
        ? 100.0
        : (horasCompletadas / horasRequeridas) * 100;

    resultado.add(
      SemaforoAreaViewModel(
        area: area,
        // En el anual un legajo puede repetirse si cambió de equipo.
        cantidadColaboradores: listaItems
            .map((item) => item.empleado.legajo)
            .toSet()
            .length,
        horasCompletadas: horasCompletadas,
        horasRequeridas: horasRequeridas,
        porcentajeCumplimiento: porcentaje,
        semaforo: EstadoSemaforo.desdePorcentaje(porcentaje),
      ),
    );
  });

  resultado.sort(
    (a, b) => b.porcentajeCumplimiento.compareTo(a.porcentajeCumplimiento),
  );
  return resultado;
});
