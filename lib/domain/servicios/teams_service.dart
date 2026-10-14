import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado_historial.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

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

  List<Empleado> filtrarEmpleadosPorPeriodo({
    required List<Empleado> empleados,
    List<EmpleadoHistorial>? historial,
    required int anio,
    required int mes,
    required bool esAnual,
  }) {
    final inicioSiguiente = DateTime(anio, esAnual ? 13 : mes + 1);
    final ultimoDia = DateTime(anio, esAnual ? 13 : mes + 1, 0);
    final vigenciasPorLegajo = <String, List<EmpleadoHistorial>>{};
    for (final vigencia in historial ?? <EmpleadoHistorial>[]) {
      vigenciasPorLegajo.putIfAbsent(vigencia.legajo, () => []).add(vigencia);
    }

    final elegibles = <Empleado>[];
    for (final empleado in empleados) {
      final ingreso = empleado.fechaIngreso;
      if (ingreso == null) continue;
      final fechaIngreso = DateTime(ingreso.year, ingreso.month, ingreso.day);
      if (fechaIngreso.isAfter(ultimoDia)) continue;
      if (historial == null) {
        if (empleado.activo) elegibles.add(empleado);
        continue;
      }

      final vigencias = vigenciasPorLegajo[empleado.legajo] ?? [];
      final vigentes = vigencias.where((vigencia) {
        final hasta = vigencia.vigenteHasta;
        return vigencia.vigenteDesde.isBefore(inicioSiguiente) &&
            (hasta == null || !hasta.isBefore(inicioSiguiente));
      }).toList();
      if (vigentes.isEmpty && vigencias.isNotEmpty) {
        // Leandro: llama a reduce para recuperar el primer estado conocido sin usar el activo actual.
        final primera = vigencias.reduce(
          (anterior, actual) =>
              actual.vigenteDesde.isBefore(anterior.vigenteDesde)
              ? actual
              : anterior,
        );
        if (!primera.vigenteDesde.isBefore(inicioSiguiente)) {
          vigentes.addAll(
            vigencias.where(
              (vigencia) =>
                  vigencia.vigenteDesde.isAtSameMomentAs(primera.vigenteDesde),
            ),
          );
        }
      }
      if (vigentes.length != 1) {
        throw StateError(
          'El historial del colaborador ${empleado.legajo} no tiene una '
          'vigencia única al cierre de $mes/$anio.',
        );
      }
      final vigente = vigentes.single;
      if (vigente.activo) {
        // Leandro: llama a reconstruir para usar el estado, seniority y equipo vigentes al cierre del mes.
        elegibles.add(vigente.reconstruir(empleado));
      }
    }
    return elegibles;
  }

  int? ultimoMesConDatos({
    required List<CargaDeHorasCRM> cargas,
    required List<CertificacionMoodle> certificaciones,
    required int anio,
  }) {
    for (var mes = 12; mes >= 1; mes--) {
      if (tieneDatosEnPeriodo(
        cargas: cargas,
        certificaciones: certificaciones,
        anio: anio,
        mes: mes,
        esAnual: false,
      )) {
        return mes;
      }
    }
    return null;
  }

  List<CumplimientoEmpleado> calcularCumplimientoAnual({
    required List<Empleado> empleados,
    List<EmpleadoHistorial>? historial,
    required List<Curso> cursos,
    required List<CargaDeHorasCRM> cargas,
    required List<CertificacionMoodle> certificaciones,
    required int anio,
    required CumplimientoService cumplimientoService,
  }) {
    final acumulados = <String, CumplimientoEmpleado>{};

    for (var mes = 1; mes <= 12; mes++) {
      // Leandro: llama a tieneDatosEnPeriodo para acumular sólo los meses que tienen registros CRM o LMS.
      if (!tieneDatosEnPeriodo(
        cargas: cargas,
        certificaciones: certificaciones,
        anio: anio,
        mes: mes,
        esAnual: false,
      )) {
        continue;
      }

      // Leandro: llama a calcularCumplimientoGlobal para conservar los límites mensuales y la elegibilidad al cierre de cada mes.
      final cumplimientosMensuales = cumplimientoService
          .calcularCumplimientoGlobal(
            empleados: filtrarEmpleadosPorPeriodo(
              empleados: empleados,
              historial: historial,
              anio: anio,
              mes: mes,
              esAnual: false,
            ),
            cursos: cursos,
            cargasDeHoras: filtrarCargasPorPeriodo(
              cargas: cargas,
              anio: anio,
              mes: mes,
              esAnual: false,
            ),
            certificacionesMoodle: filtrarCertificacionesPorPeriodo(
              certificaciones: certificaciones,
              anio: anio,
              mes: mes,
              esAnual: false,
            ),
          );

      for (final mensual in cumplimientosMensuales) {
        final empleado = mensual.empleado;
        final clave =
            '${empleado.legajo}::${empleado.area}::'
            '${_nombreEquipoNormalizado(empleado.equipo)}';
        final anterior = acumulados[clave];
        acumulados[clave] = CumplimientoEmpleado(
          empleado: mensual.empleado,
          horasValidas: {
            for (final tipo in TipoCurso.values)
              // Leandro: llama a horasAplicablesAlObjetivo para sumar horas ya limitadas en cada mes.
              tipo:
                  (anterior?.horasValidas[tipo] ?? 0) +
                  mensual.horasAplicablesAlObjetivo(tipo),
          },
          horasDeclaradas: {
            for (final tipo in TipoCurso.values)
              tipo:
                  (anterior?.horasDeclaradas[tipo] ?? 0) +
                  (mensual.horasDeclaradas[tipo] ?? 0),
          },
          horasRequeridas: {
            for (final tipo in TipoCurso.values)
              tipo:
                  (anterior?.horasRequeridas[tipo] ?? 0) +
                  (mensual.horasRequeridas[tipo] ?? 0),
          },
        );
      }
    }

    return acumulados.values.toList();
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
    final miembros = cumplimientos.where((cumplimiento) {
      final empleado = cumplimiento.empleado;
      return _normalizarComparacion(empleado.area) == areaBuscada &&
          _normalizarComparacion(_nombreEquipoNormalizado(empleado.equipo)) ==
              equipoBuscado;
    }).toList();

    if (miembros.isEmpty) return null;

    // Leandro: llama a _crearResumenEquipo antes de ordenar la tabla para conservar la misma fuente de líder que la vista global.
    final resumen = _crearResumenEquipo(miembros);
    miembros.sort(
      (a, b) => a.empleado.nombreCompleto.compareTo(b.empleado.nombreCompleto),
    );

    return DetalleEquipoGeneral(resumen: resumen, miembros: miembros);
  }

  ResumenEquiposPeriodo calcularResumenPeriodo(
    List<CumplimientoEmpleado> cumplimientos, {
    int? colaboradoresAlCierre,
  }) {
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
      colaboradores: colaboradoresAlCierre ?? colaboradores,
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
