import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class CumplimientoEmpleado {
  final Empleado empleado;
  final Map<TipoCurso, double> horasValidas;
  final Map<TipoCurso, double> horasDeclaradas;
  final Map<TipoCurso, double> horasRequeridas;

  CumplimientoEmpleado({
    required this.empleado,
    required this.horasValidas,
    required this.horasDeclaradas,
    required this.horasRequeridas,
  });

  Map<TipoCurso, double> get horasCompletadas => horasValidas;

  /// Horas que pueden aplicarse al objetivo de una categoría.
  /// Una categoría no requerida puede tener actividad, pero no suma cumplimiento.
  double horasAplicablesAlObjetivo(TipoCurso tipo) {
    final requeridas = horasRequeridas[tipo] ?? 0.0;
    if (requeridas <= 0) return 0.0;

    return (horasValidas[tipo] ?? 0.0).clamp(0.0, requeridas).toDouble();
  }

  double get totalHorasValidas => horasRequeridas.entries.fold(
    0.0,
    (total, requisito) => total + horasAplicablesAlObjetivo(requisito.key),
  );

  double get totalHorasCompletadas => totalHorasValidas;

  double get totalHorasDeclaradas =>
      horasDeclaradas.values.fold(0.0, (total, horas) => total + horas);

  double get totalHorasRequeridas =>
      horasRequeridas.values.fold(0.0, (acc, hs) => acc + hs);

  double get porcentajeTotal => totalHorasRequeridas == 0
      ? 100.0
      : (totalHorasValidas / totalHorasRequeridas * 100).clamp(0.0, 100.0);

  bool get cumpleObjetivo => horasRequeridas.entries.every(
    (req) => req.value == 0 || (horasValidas[req.key] ?? 0) >= req.value,
  );
}
