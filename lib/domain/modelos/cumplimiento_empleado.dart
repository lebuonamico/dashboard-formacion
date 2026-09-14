import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class CumplimientoEmpleado {
  final Empleado empleado;
  final Map<TipoCurso, double> horasCompletadas;
  final Map<TipoCurso, double> horasRequeridas;

  CumplimientoEmpleado({
    required this.empleado,
    required this.horasCompletadas,
    required this.horasRequeridas,
  });

  double get totalHorasCompletadas =>
      horasCompletadas.values.fold(0.0, (acc, hs) => acc + hs);

  double get totalHorasRequeridas =>
      horasRequeridas.values.fold(0.0, (acc, hs) => acc + hs);

  double get porcentajeTotal => totalHorasRequeridas == 0
      ? 100.0
      : (totalHorasCompletadas / totalHorasRequeridas * 100).clamp(0.0, 100.0);

  bool get cumpleObjetivo =>
      horasRequeridas.entries.every((req) =>
          (horasCompletadas[req.key] ?? 0) >= req.value);
}