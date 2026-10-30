import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';

/// Columnas por las que se pueden ordenar las tablas de integrantes.
enum OrdenMiembros {
  legajo,
  colaborador,
  equipo,
  seniority,
  horas,
  cumplimiento,
}

/// Columna activa y sentido del orden de una tabla de integrantes.
class EstadoOrdenMiembros {
  final OrdenMiembros? columna;
  final bool ascendente;

  const EstadoOrdenMiembros({this.columna, this.ascendente = true});

  /// Primer click en una columna: ascendente; click en la misma: invierte.
  EstadoOrdenMiembros alternar(OrdenMiembros nueva) => EstadoOrdenMiembros(
    columna: nueva,
    ascendente: columna == nueva ? !ascendente : true,
  );

  /// Copia ordenada; sin columna activa devuelve el orden original.
  List<CumplimientoEmpleado> aplicar(List<CumplimientoEmpleado> miembros) {
    final actual = columna;
    if (actual == null) return miembros;
    final ordenados = [...miembros];
    ordenados.sort((a, b) {
      final resultado = _comparar(actual, a, b);
      // A igual valor, por nombre para que el orden sea estable.
      final desempate = resultado != 0
          ? resultado
          : a.empleado.nombreCompleto.toLowerCase().compareTo(
              b.empleado.nombreCompleto.toLowerCase(),
            );
      return ascendente ? desempate : -desempate;
    });
    return ordenados;
  }

  static int _comparar(
    OrdenMiembros columna,
    CumplimientoEmpleado a,
    CumplimientoEmpleado b,
  ) => switch (columna) {
    OrdenMiembros.legajo => _compararLegajo(
      a.empleado.legajo,
      b.empleado.legajo,
    ),
    OrdenMiembros.colaborador =>
      a.empleado.nombreCompleto.toLowerCase().compareTo(
        b.empleado.nombreCompleto.toLowerCase(),
      ),
    OrdenMiembros.equipo => a.empleado.equipo.trim().toLowerCase().compareTo(
      b.empleado.equipo.trim().toLowerCase(),
    ),
    OrdenMiembros.seniority => a.empleado.seniority.index.compareTo(
      b.empleado.seniority.index,
    ),
    OrdenMiembros.horas => a.totalHorasValidas.compareTo(
      b.totalHorasValidas,
    ),
    OrdenMiembros.cumplimiento => a.porcentajeTotal.compareTo(
      b.porcentajeTotal,
    ),
  };

  /// Legajos numéricos por valor ("9" antes que "10"); el resto como texto.
  static int _compararLegajo(String a, String b) {
    final numeroA = int.tryParse(a.trim());
    final numeroB = int.tryParse(b.trim());
    if (numeroA != null && numeroB != null) return numeroA.compareTo(numeroB);
    return a.compareTo(b);
  }
}
