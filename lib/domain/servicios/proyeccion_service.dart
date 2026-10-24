import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

/// Si, con la tendencia de cada colaborador, se llega a la meta de fin de año.
enum EstadoProyeccion {
  enCamino('En camino'),
  alcanzable('Alcanzable'),
  enRiesgo('En riesgo');

  final String label;
  const EstadoProyeccion(this.label);

  /// [porcentaje] es la parte de la meta que se proyecta cubrir.
  static EstadoProyeccion desdePorcentaje(double porcentaje) {
    if (porcentaje >= 100) return EstadoProyeccion.enCamino;
    if (porcentaje >= 85) return EstadoProyeccion.alcanzable;
    return EstadoProyeccion.enRiesgo;
  }
}

/// Proyección de una categoría para un colaborador, en horas.
class ProyeccionCategoria {
  final TipoCurso tipo;

  /// Horas sin tope de los meses con datos hasta el corte.
  final double acumulado;

  /// Objetivo de los meses con datos hasta el corte más los que faltan.
  final double meta;

  /// Acumulado más lo que estima la tendencia para los meses que faltan.
  final double proyectado;

  const ProyeccionCategoria({
    required this.tipo,
    required this.acumulado,
    required this.meta,
    required this.proyectado,
  });

  bool get llega => proyectado >= meta;

  /// Horas que le faltan a fin de año con su tendencia.
  double get falta => llega ? 0 : meta - proyectado;
}

/// Proyección a fin de año de un colaborador, solo con las categorías que
/// pide su seniority.
class ProyeccionEmpleado {
  final String legajo;
  final int mesCorte;
  final List<ProyeccionCategoria> categorias;

  /// [porcentaje] de su proyección cortada en el mes con datos anterior;
  /// `null` si no hay un mes anterior en el que haya estado.
  final double? porcentajeAnterior;

  const ProyeccionEmpleado({
    required this.legajo,
    required this.mesCorte,
    required this.categorias,
    this.porcentajeAnterior,
  });

  /// Puntos de la meta que mejoró (o empeoró) contra el mes anterior.
  double? get variacion =>
      porcentajeAnterior == null ? null : porcentaje - porcentajeAnterior!;

  int get mesesRestantes => 12 - mesCorte;

  /// Cumple todas sus categorías.
  bool get llega => categorias.every((c) => c.llega);

  /// Horas proyectadas, cada categoría topeada en su meta.
  double get proyeccion => categorias.fold(
    0,
    (t, c) => t + (c.proyectado < c.meta ? c.proyectado : c.meta),
  );

  double get meta => categorias.fold(0, (t, c) => t + c.meta);

  double get porcentaje => meta == 0 ? 100 : proyeccion / meta * 100;

  EstadoProyeccion get estado => EstadoProyeccion.desdePorcentaje(porcentaje);

  /// Categorías que no llegan, la que más falta primero.
  List<ProyeccionCategoria> get faltantes =>
      categorias.where((c) => !c.llega).toList()
        ..sort((a, b) => b.falta.compareTo(a.falta));
}

/// Proyección a fin de año de una sección, cortada en [mesCorte]. Se calcula
/// por colaborador y categoría y después se agrupa: las horas de una persona
/// nunca cubren lo que le falta a otra, ni las de una categoría a otra.
/// Los valores en horas son promedios por persona.
class ProyeccionAnual {
  final int mesCorte;
  final int colaboradores;

  /// Colaboradores que, con su tendencia, cumplen todas sus categorías.
  final int llegan;

  /// Horas proyectadas a diciembre, cada una topeada en la meta de su
  /// categoría.
  final double proyeccion;

  /// Objetivo de los meses con datos hasta el corte más los que faltan.
  final double meta;

  /// Horas acumuladas hasta el corte, topeadas en la meta de su categoría.
  final double acumulado;

  /// Horas que les faltan, con su tendencia, a quienes no llegan.
  final double faltante;

  final EstadoProyeccion estado;

  /// Cumplimiento del mes de corte, con el tope mensual, en porcentaje.
  final double cumplimientoMes;

  /// Horas del mes de corte con el tope mensual.
  final double ritmoReciente;

  /// Horas del mes anterior al corte con el tope mensual; `null` si ese mes no
  /// tiene datos.
  final double? ritmoMesAnterior;

  /// [porcentaje] de la proyección cortada en el mes con datos anterior;
  /// `null` si no hay un mes anterior con datos.
  final double? porcentajeAnterior;

  const ProyeccionAnual({
    required this.mesCorte,
    required this.colaboradores,
    required this.llegan,
    required this.proyeccion,
    required this.meta,
    required this.acumulado,
    required this.faltante,
    required this.estado,
    required this.cumplimientoMes,
    required this.ritmoReciente,
    required this.ritmoMesAnterior,
    this.porcentajeAnterior,
  });

  int get mesesRestantes => 12 - mesCorte;

  double get porcentaje => meta == 0 ? 100 : proyeccion / meta * 100;

  /// Puntos de la meta que mejoró (o empeoró) la proyección contra la del
  /// mes anterior.
  double? get variacionProyeccion =>
      porcentajeAnterior == null ? null : porcentaje - porcentajeAnterior!;

  /// Horas por persona y por mes que hay que sumar a la tendencia para
  /// llegar; 0 si ya no quedan meses.
  double get ajuste => mesesRestantes == 0 ? 0 : faltante / mesesRestantes;

  /// Diferencia de horas por persona contra el mes anterior.
  double? get variacion =>
      ritmoMesAnterior == null ? null : ritmoReciente - ritmoMesAnterior!;

  /// Variación porcentual contra el mes anterior; `null` si no se puede
  /// comparar.
  double? get variacionPorcentual {
    final anterior = ritmoMesAnterior;
    if (anterior == null || anterior == 0) return null;
    return (ritmoReciente - anterior) / anterior * 100;
  }
}

class ProyeccionService {
  const ProyeccionService();

  /// [porMes] tiene el cumplimiento mensual de los meses con datos hasta el
  /// corte; un mes sin datos de nadie no está y no cuenta. Se proyecta a los
  /// colaboradores del mes de corte, con todo su historial del año. Devuelve
  /// `null` si el mes de corte no tiene colaboradores.
  ProyeccionAnual? calcular({
    required Map<int, List<CumplimientoEmpleado>> porMes,
    required int mesCorte,
  }) {
    final actual = _calcular(porMes: porMes, mesCorte: mesCorte);
    if (actual == null) return null;

    // La misma proyección, cortada en el mes con datos anterior.
    final anteriores =
        porMes.entries
            .where((e) => e.key < mesCorte && e.value.isNotEmpty)
            .map((e) => e.key)
            .toList()
          ..sort();
    if (anteriores.isEmpty) return actual;
    final previa = _calcular(porMes: porMes, mesCorte: anteriores.last);
    return ProyeccionAnual(
      mesCorte: actual.mesCorte,
      colaboradores: actual.colaboradores,
      llegan: actual.llegan,
      proyeccion: actual.proyeccion,
      meta: actual.meta,
      acumulado: actual.acumulado,
      faltante: actual.faltante,
      estado: actual.estado,
      cumplimientoMes: actual.cumplimientoMes,
      ritmoReciente: actual.ritmoReciente,
      ritmoMesAnterior: actual.ritmoMesAnterior,
      porcentajeAnterior: previa?.porcentaje,
    );
  }

  ProyeccionAnual? _calcular({
    required Map<int, List<CumplimientoEmpleado>> porMes,
    required int mesCorte,
  }) {
    final delCorte = porMes[mesCorte] ?? const [];
    if (delCorte.isEmpty) return null;

    final empleados = proyectarEmpleados(porMes: porMes, mesCorte: mesCorte);
    var proyeccion = 0.0;
    var meta = 0.0;
    var acumulado = 0.0;
    var faltante = 0.0;
    for (final empleado in empleados) {
      proyeccion += empleado.proyeccion;
      meta += empleado.meta;
      for (final categoria in empleado.categorias) {
        acumulado += categoria.acumulado < categoria.meta
            ? categoria.acumulado
            : categoria.meta;
        faltante += categoria.falta;
      }
    }
    final llegan = empleados.where((e) => e.llega).length;

    final n = empleados.length;
    double conTope(List<CumplimientoEmpleado> items) =>
        items.fold<double>(0, (t, c) => t + c.totalHorasCompletadas);
    final horasCorte = conTope(delCorte);
    final objetivoCorte = delCorte.fold<double>(
      0,
      (t, c) => t + c.totalHorasRequeridas,
    );
    final anterior = porMes[mesCorte - 1] ?? const [];

    return ProyeccionAnual(
      mesCorte: mesCorte,
      colaboradores: n,
      llegan: llegan,
      proyeccion: proyeccion / n,
      meta: meta / n,
      acumulado: acumulado / n,
      faltante: faltante / n,
      estado: EstadoProyeccion.desdePorcentaje(
        meta == 0 ? 100 : proyeccion / meta * 100,
      ),
      cumplimientoMes: objetivoCorte == 0
          ? 100
          : horasCorte / objetivoCorte * 100,
      ritmoReciente: horasCorte / n,
      ritmoMesAnterior: anterior.isEmpty
          ? null
          : conTope(anterior) / anterior.length,
    );
  }

  /// Proyección de cada colaborador del mes de corte, por categoría, con todo
  /// su historial del año en [porMes]. Solo incluye las categorías con meta.
  List<ProyeccionEmpleado> proyectarEmpleados({
    required Map<int, List<CumplimientoEmpleado>> porMes,
    required int mesCorte,
  }) {
    // Historial de cada colaborador por legajo: mes -> cumplimiento.
    final historial = <String, Map<int, CumplimientoEmpleado>>{};
    for (final entry in porMes.entries) {
      if (entry.key > mesCorte) continue;
      for (final item in entry.value) {
        (historial[item.empleado.legajo] ??= {})[entry.key] = item;
      }
    }

    final restantes = 12 - mesCorte;
    final legajos = {
      for (final item in porMes[mesCorte] ?? const <CumplimientoEmpleado>[])
        item.empleado.legajo,
    };

    return [
      for (final legajo in legajos)
        () {
          final meses = historial[legajo]!;
          final corte = meses[mesCorte]!;
          final categorias = <ProyeccionCategoria>[];

          for (final tipo in TipoCurso.values) {
            final puntos = <({int mes, double horas})>[];
            var meta = 0.0;
            for (final MapEntry(key: mes, value: item) in meses.entries) {
              final requeridas = item.horasRequeridas[tipo] ?? 0;
              meta += requeridas;
              // Sin tope mensual; solo cuentan los meses en que era requerida.
              puntos.add((
                mes: mes,
                horas: requeridas > 0 ? item.horasValidas[tipo] ?? 0 : 0,
              ));
            }
            meta += (corte.horasRequeridas[tipo] ?? 0) * restantes;
            if (meta <= 0) continue;

            final acumulado = puntos.fold<double>(0, (t, p) => t + p.horas);
            final tendencia = _regresion(puntos);
            var futuro = 0.0;
            for (var mes = mesCorte + 1; mes <= 12; mes++) {
              final estimado = tendencia(mes);
              if (estimado > 0) futuro += estimado;
            }
            categorias.add(
              ProyeccionCategoria(
                tipo: tipo,
                acumulado: acumulado,
                meta: meta,
                proyectado: acumulado + futuro,
              ),
            );
          }
          return ProyeccionEmpleado(
            legajo: legajo,
            mesCorte: mesCorte,
            categorias: categorias,
          );
        }(),
    ];
  }

  /// Regresión lineal simple de las horas sobre el mes. Con un solo mes, la
  /// tendencia es plana.
  double Function(int mes) _regresion(List<({int mes, double horas})> puntos) {
    final n = puntos.length;
    final mediaX = puntos.fold<double>(0, (t, p) => t + p.mes) / n;
    final mediaY = puntos.fold<double>(0, (t, p) => t + p.horas) / n;
    var covarianza = 0.0;
    var varianza = 0.0;
    for (final p in puntos) {
      covarianza += (p.mes - mediaX) * (p.horas - mediaY);
      varianza += (p.mes - mediaX) * (p.mes - mediaX);
    }
    final pendiente = varianza == 0 ? 0.0 : covarianza / varianza;
    final ordenada = mediaY - pendiente * mediaX;
    return (mes) => ordenada + pendiente * mes;
  }
}
