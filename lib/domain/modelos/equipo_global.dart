import 'package:app_finnegans/domain/modelos/estado_equipo.dart';

/// Leandro: Resultado que EquiposService entrega al provider y luego a los widgets.
class EquipoGlobalViewModel {
  final String id;
  final String nombre;
  final String area;
  final String lider;
  final int cantidadIntegrantes;
  final int integrantesEnObjetivo;
  final double horasRealizadas;
  final double horasObjetivo;
  final double desvioHoras;
  final double horasNegocio;
  final double horasBlandas;
  final double horasLibres;
  final double horasDictado;
  final double promedioPorColaborador;
  final double porcentajeCumplimiento;
  final EstadoEquipo estado;

  const EquipoGlobalViewModel({
    required this.id,
    required this.nombre,
    required this.area,
    required this.lider,
    required this.cantidadIntegrantes,
    required this.integrantesEnObjetivo,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.desvioHoras,
    required this.horasNegocio,
    required this.horasBlandas,
    required this.horasLibres,
    required this.horasDictado,
    required this.promedioPorColaborador,
    required this.porcentajeCumplimiento,
    required this.estado,
  });
}
