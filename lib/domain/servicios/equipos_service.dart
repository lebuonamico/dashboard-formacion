import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/equipo_global.dart';
import 'package:app_finnegans/domain/modelos/estado_equipo.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

/// Leandro: Servicio de negocio de Equipos.
/// Leandro: Acá viven las reglas; los providers sólo coordinan datos y estado de UI.
class EquiposService {
  // Leandro: Recibe todas las cargas CRM y devuelve sólo las del período elegido.
  List<CargaDeHorasCRM> filtrarCargasPorPeriodo({
    required List<CargaDeHorasCRM> cargas,
    required int anio,
    required int mes,
    required bool esAnual,
  }) {
    return cargas.where((carga) {
      final coincideAnio = carga.fecha.year == anio;
      if (esAnual) return coincideAnio;

      return coincideAnio && carga.fecha.month == mes;
    }).toList();
  }

  // Leandro: Para la vista anual conserva las horas cargadas y multiplica el objetivo por 12.
  List<CumplimientoEmpleado> convertirObjetivoMensualAAnual(
    List<CumplimientoEmpleado> cumplimientos, {
    int mesesConRegistros = 12,
  }) {
    final meses = mesesConRegistros.clamp(1, 12);
    return cumplimientos.map((cumplimiento) {
      final horasRequeridasAnuales = cumplimiento.horasRequeridas.map(
        (tipo, horas) => MapEntry(tipo, horas * meses),
      );

      return CumplimientoEmpleado(
        empleado: cumplimiento.empleado,
        horasCompletadas: cumplimiento.horasCompletadas,
        horasRequeridas: horasRequeridasAnuales,
      );
    }).toList();
  }

  // Leandro: Agrupa los cumplimientos individuales y genera un resumen por equipo.
  List<EquipoGlobalViewModel> calcularEquiposGlobales(
    List<CumplimientoEmpleado> cumplimientos,
  ) {
    final agrupadoPorEquipo = <String, List<CumplimientoEmpleado>>{};

    // Leandro: Área + equipo evita mezclar nombres iguales pertenecientes a áreas distintas.
    for (final cumplimiento in cumplimientos) {
      final empleado = cumplimiento.empleado;
      final nombreEquipo = _nombreEquipoNormalizado(empleado.equipo);
      final clave = '${empleado.area}::$nombreEquipo';

      agrupadoPorEquipo.putIfAbsent(clave, () => []).add(cumplimiento);
    }

    final equipos = <EquipoGlobalViewModel>[];
    for (final miembros in agrupadoPorEquipo.values) {
      equipos.add(_crearResumenEquipo(miembros));
    }

    equipos.sort(_compararEquiposPorPrioridad);
    return equipos;
  }

  EquipoGlobalViewModel _crearResumenEquipo(
    List<CumplimientoEmpleado> miembros,
  ) {
    // Leandro: Este método suma horas, objetivos, categorías e integrantes del equipo.
    final primerMiembro = miembros.first.empleado;
    final nombreEquipo = _nombreEquipoNormalizado(primerMiembro.equipo);
    final horasRealizadas = miembros.fold<double>(
      0,
      (total, miembro) => total + miembro.totalHorasCompletadas,
    );
    final horasObjetivo = miembros.fold<double>(
      0,
      (total, miembro) => total + miembro.totalHorasRequeridas,
    );
    final porcentajeCumplimiento = horasObjetivo == 0
        ? 100.0
        : (horasRealizadas / horasObjetivo) * 100;
    final cantidadIntegrantes = miembros.length;
    final integrantesEnObjetivo = miembros
        .where((miembro) => miembro.cumpleObjetivo)
        .length;

    return EquipoGlobalViewModel(
      id: _crearTeamId(primerMiembro.area, nombreEquipo),
      nombre: nombreEquipo,
      area: primerMiembro.area,
      lider: primerMiembro.gerente.trim().isEmpty
          ? 'Sin líder asignado'
          : primerMiembro.gerente,
      cantidadIntegrantes: cantidadIntegrantes,
      integrantesEnObjetivo: integrantesEnObjetivo,
      horasRealizadas: horasRealizadas,
      horasObjetivo: horasObjetivo,
      desvioHoras: horasRealizadas - horasObjetivo,
      horasNegocio: _sumarHorasCategoria(
        miembros,
        TipoCurso.habilidadesDeNegocio,
      ),
      horasBlandas: _sumarHorasCategoria(
        miembros,
        TipoCurso.habilidadesBlandas,
      ),
      horasLibres: _sumarHorasCategoria(miembros, TipoCurso.libresExploracion),
      horasDictado: _sumarHorasCategoria(
        miembros,
        TipoCurso.dictadoCapacitaciones,
      ),
      promedioPorColaborador: cantidadIntegrantes == 0
          ? 0
          : horasRealizadas / cantidadIntegrantes,
      porcentajeCumplimiento: porcentajeCumplimiento,
      estado: calcularEstadoEquipo(
        porcentajeCumplimiento: porcentajeCumplimiento,
        cantidadIntegrantes: cantidadIntegrantes,
        integrantesEnObjetivo: integrantesEnObjetivo,
      ),
    );
  }

  // Leandro: En objetivo exige horas completas y que todos cumplan individualmente.
  // Así una persona con horas de más no compensa a otra que todavía no cumplió.
  EstadoEquipo calcularEstadoEquipo({
    required double porcentajeCumplimiento,
    required int cantidadIntegrantes,
    required int integrantesEnObjetivo,
  }) {
    final todosEnObjetivo =
        cantidadIntegrantes > 0 && integrantesEnObjetivo == cantidadIntegrantes;

    if (porcentajeCumplimiento >= 100.0 && todosEnObjetivo) {
      return EstadoEquipo.enObjetivo;
    }

    if (porcentajeCumplimiento >= 70.0 || integrantesEnObjetivo > 0) {
      return EstadoEquipo.enRiesgo;
    }

    return EstadoEquipo.critico;
  }

  int _compararEquiposPorPrioridad(
    EquipoGlobalViewModel a,
    EquipoGlobalViewModel b,
  ) {
    final estado = _ordenEstado(a.estado).compareTo(_ordenEstado(b.estado));
    if (estado != 0) return estado;

    final cumplimiento = a.porcentajeCumplimiento.compareTo(
      b.porcentajeCumplimiento,
    );
    if (cumplimiento != 0) return cumplimiento;

    return a.nombre.compareTo(b.nombre);
  }

  int _ordenEstado(EstadoEquipo estado) {
    switch (estado) {
      case EstadoEquipo.critico:
        return 0;
      case EstadoEquipo.enRiesgo:
        return 1;
      case EstadoEquipo.enObjetivo:
        return 2;
    }
  }

  double _sumarHorasCategoria(
    List<CumplimientoEmpleado> miembros,
    TipoCurso tipo,
  ) {
    return miembros.fold<double>(
      0,
      (total, miembro) => total + (miembro.horasCompletadas[tipo] ?? 0),
    );
  }

  String _nombreEquipoNormalizado(String equipo) {
    return equipo.trim().isEmpty ? 'Sin equipo asignado' : equipo.trim();
  }

  String _crearTeamId(String area, String equipo) {
    return '${_normalizarId(area)}-${_normalizarId(equipo)}';
  }

  String _normalizarId(String valor) {
    return valor
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
