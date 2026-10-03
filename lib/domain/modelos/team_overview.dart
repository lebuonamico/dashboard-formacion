import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';

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

/// Totales del período que consume la pantalla de Equipos.
class ResumenEquiposPeriodo {
  final List<EquipoGlobalViewModel> equipos;
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

  const ResumenEquiposPeriodo({
    required this.equipos,
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

  int get totalEquipos => equipos.length;
  double get desvioHoras => horasRealizadas - horasObjetivo;
  double get cumplimientoGlobal =>
      horasObjetivo == 0 ? 0 : horasRealizadas / horasObjetivo * 100;
}

/// Equipo seleccionado junto con los integrantes evaluados en el período.
class DetalleEquipoGeneral {
  final EquipoGlobalViewModel resumen;
  final List<CumplimientoEmpleado> miembros;

  const DetalleEquipoGeneral({required this.resumen, required this.miembros});
}
