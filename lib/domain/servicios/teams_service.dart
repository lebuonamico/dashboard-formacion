import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class EquiposService {
  bool tieneDatosEnPeriodo({
    required List<CargaDeHorasCRM> cargas,
    required List<CertificacionMoodle> certificaciones,
    required int anio,
    required int mes,
    required bool esAnual,
  }) {
    bool perteneceAlPeriodo(DateTime fecha) =>
        fecha.year == anio && (esAnual || fecha.month == mes);

    // Leandro: llama a perteneceAlPeriodo para reconocer los registros CRM o LMS del mes o año elegido.
    return cargas.any((carga) => perteneceAlPeriodo(carga.fecha)) ||
        certificaciones.any((certificacion) {
          final fecha = certificacion.fechaFinalizacion;
          return fecha != null && perteneceAlPeriodo(fecha);
        });
  }

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

  List<CertificacionMoodle> filtrarCertificacionesPorPeriodo({
    required List<CertificacionMoodle> certificaciones,
    required int anio,
    required int mes,
    required bool esAnual,
  }) {
    return certificaciones.where((certificacion) {
      final fecha = certificacion.fechaFinalizacion;
      if (!certificacion.finalizoCurso || fecha == null || fecha.year != anio) {
        return false;
      }
      return esAnual || fecha.month == mes;
    }).toList();
  }

  // La población del período depende del ingreso, aunque no haya actividad CRM/LMS.
  List<Empleado> filtrarEmpleadosPorPeriodo({
    required List<Empleado> empleados,
    required int anio,
    required int mes,
    required bool esAnual,
  }) {
    final ultimoDia = DateTime(anio, esAnual ? 13 : mes + 1, 0);

    return empleados.where((empleado) {
      final ingreso = empleado.fechaIngreso;
      if (ingreso == null) return false;
      final fechaIngreso = DateTime(ingreso.year, ingreso.month, ingreso.day);
      return !fechaIngreso.isAfter(ultimoDia);
    }).toList();
  }

  int contarMesesConRegistros({
    required List<CargaDeHorasCRM> cargas,
    required List<CertificacionMoodle> certificaciones,
    required int anio,
  }) {
    final meses = cargas
        .where((carga) => carga.fecha.year == anio)
        .map((carga) => carga.fecha.month)
        .toSet();
    meses.addAll(
      certificaciones
          .where(
            (certificacion) =>
                certificacion.finalizoCurso &&
                certificacion.fechaFinalizacion?.year == anio,
          )
          .map((certificacion) => certificacion.fechaFinalizacion!.month),
    );
    return meses.length;
  }

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
        horasValidas: cumplimiento.horasValidas,
        horasDeclaradas: cumplimiento.horasDeclaradas,
        horasRequeridas: horasRequeridasAnuales,
      );
    }).toList();
  }

  List<EquipoGlobalViewModel> calcularEquiposGlobales(
    List<CumplimientoEmpleado> cumplimientos,
  ) {
    final agrupadoPorEquipo = <String, List<CumplimientoEmpleado>>{};

    for (final cumplimiento in cumplimientos) {
      final empleado = cumplimiento.empleado;
      final nombreEquipo = _nombreEquipoNormalizado(empleado.equipo);
      final clave = '${empleado.area}::$nombreEquipo';

      agrupadoPorEquipo.putIfAbsent(clave, () => []).add(cumplimiento);
    }

    final equipos = <EquipoGlobalViewModel>[];
    for (final miembros in agrupadoPorEquipo.values) {
      // Leandro: llama a _crearResumenEquipo para obtener los indicadores de cada grupo de integrantes.
      equipos.add(_crearResumenEquipo(miembros));
    }

    // Leandro: llama a _compararEquiposPorPrioridad para mostrar primero los equipos que requieren atención.
    equipos.sort(_compararEquiposPorPrioridad);
    return equipos;
  }

  DetalleEquipoGeneral? obtenerDetalleEquipo({
    required List<CumplimientoEmpleado> cumplimientos,
    required String area,
    required String equipo,
  }) {
    final areaBuscada = _normalizarComparacion(area);
    final equipoBuscado = _normalizarComparacion(
      _nombreEquipoNormalizado(equipo),
    );
    final miembros =
        cumplimientos.where((cumplimiento) {
          final empleado = cumplimiento.empleado;
          return _normalizarComparacion(empleado.area) == areaBuscada &&
              _normalizarComparacion(
                    _nombreEquipoNormalizado(empleado.equipo),
                  ) ==
                  equipoBuscado;
        }).toList()..sort(
          (a, b) =>
              a.empleado.nombreCompleto.compareTo(b.empleado.nombreCompleto),
        );

    if (miembros.isEmpty) return null;

    return DetalleEquipoGeneral(
      // Leandro: llama a _crearResumenEquipo para usar en el detalle los mismos indicadores que en la vista global.
      resumen: _crearResumenEquipo(miembros),
      miembros: miembros,
    );
  }

  ResumenEquiposPeriodo calcularResumenPeriodo(
    List<CumplimientoEmpleado> cumplimientos,
  ) {
    // Leandro: llama a calcularEquiposGlobales para obtener los equipos que se suman en los indicadores del período.
    final equipos = calcularEquiposGlobales(cumplimientos);
    var colaboradores = 0;
    var horasRealizadas = 0.0;
    var horasObjetivo = 0.0;
    var horasNegocio = 0.0;
    var horasBlandas = 0.0;
    var horasLibres = 0.0;
    var horasDictado = 0.0;
    var enObjetivo = 0;
    var enRiesgo = 0;
    var criticos = 0;

    for (final equipo in equipos) {
      colaboradores += equipo.cantidadIntegrantes;
      horasRealizadas += equipo.horasRealizadas;
      horasObjetivo += equipo.horasObjetivo;
      horasNegocio += equipo.horasNegocio;
      horasBlandas += equipo.horasBlandas;
      horasLibres += equipo.horasLibres;
      horasDictado += equipo.horasDictado;
      switch (equipo.estado) {
        case EstadoEquipo.enObjetivo:
          enObjetivo++;
          break;
        case EstadoEquipo.enRiesgo:
          enRiesgo++;
          break;
        case EstadoEquipo.critico:
          criticos++;
          break;
      }
    }

    return ResumenEquiposPeriodo(
      equipos: equipos,
      colaboradores: colaboradores,
      horasRealizadas: horasRealizadas,
      horasObjetivo: horasObjetivo,
      horasNegocio: horasNegocio,
      horasBlandas: horasBlandas,
      horasLibres: horasLibres,
      horasDictado: horasDictado,
      enObjetivo: enObjetivo,
      enRiesgo: enRiesgo,
      criticos: criticos,
    );
  }

  EquipoGlobalViewModel _crearResumenEquipo(
    List<CumplimientoEmpleado> miembros,
  ) {
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
      // Leandro: llama a _sumarHorasCategoria para separar las horas aplicables al objetivo por categoría.
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
      // Leandro: llama a calcularEstadoEquipo para asignar el estado usando el avance y el cumplimiento de los integrantes.
      estado: calcularEstadoEquipo(
        porcentajeCumplimiento: porcentajeCumplimiento,
        cantidadIntegrantes: cantidadIntegrantes,
        integrantesEnObjetivo: integrantesEnObjetivo,
      ),
    );
  }

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
      (total, miembro) => total + miembro.horasAplicablesAlObjetivo(tipo),
    );
  }

  String _nombreEquipoNormalizado(String equipo) {
    return equipo.trim().isEmpty ? 'Sin equipo asignado' : equipo.trim();
  }

  String _crearTeamId(String area, String equipo) {
    return '${_normalizarId(area)}-${_normalizarId(equipo)}';
  }

  String _normalizarComparacion(String valor) => valor.trim().toLowerCase();

  String _normalizarId(String valor) {
    return valor
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
