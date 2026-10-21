enum ModuloAsistente {
  dashboard('Dashboard'),
  areas('Áreas'),
  equipos('Equipos'),
  detalleEquipo('Detalle de equipo'),
  personas('Personas'),
  cursos('Cursos'),
  configuracion('Configuración'),
  otros('Ayuda general');

  final String etiqueta;
  const ModuloAsistente(this.etiqueta);

  static ModuloAsistente desdeRuta(String path) =>
      DestinoAsistente.desdeUri(Uri.parse(path)).modulo;
}

/// Los parámetros de navegación se usan para buscar entidades localmente.
/// Nunca se serializan la URL, los legajos ni parámetros arbitrarios.
class DestinoAsistente {
  final ModuloAsistente modulo;
  final String? area;
  final String? equipo;
  final String? legajo;
  const DestinoAsistente(this.modulo, {this.area, this.equipo, this.legajo});

  factory DestinoAsistente.desdeUri(Uri uri) {
    final p = uri.pathSegments;
    if (p.firstOrNull == 'areas') {
      return DestinoAsistente(
        p.length >= 4 && p[2] == 'equipos'
            ? ModuloAsistente.detalleEquipo
            : ModuloAsistente.areas,
        area: p.length > 1 ? p[1] : null,
        equipo: p.length >= 4 ? p[3] : null,
      );
    }
    return DestinoAsistente(switch (p.firstOrNull) {
      'dashboard' => ModuloAsistente.dashboard,
      'equipos' => ModuloAsistente.equipos,
      'empleados' => ModuloAsistente.personas,
      'cursos' => ModuloAsistente.cursos,
      'configuracion' => ModuloAsistente.configuracion,
      _ => ModuloAsistente.otros,
    }, legajo: p.firstOrNull == 'empleados' && p.length > 1 ? p[1] : null);
  }
}

class PeriodoAsistente {
  final int anio;
  final int mes;
  final bool anual;
  const PeriodoAsistente({
    required this.anio,
    required this.mes,
    this.anual = false,
  });
  Map<String, Object> toJson() => {
    'anio': anio,
    if (!anual) 'mes': mes,
    'alcance': anual ? 'anual' : 'mensual',
  };
  String get etiqueta => anual ? 'Año $anio' : '$mes/$anio';
}

enum TemaAsistente {
  general,
  areas,
  equipos,
  persona,
  cursos,
  importacion,
  conceptual,
}

class ConsultaAsistente {
  final DestinoAsistente destino;
  final TemaAsistente tema;
  final String pregunta;
  final List<PeriodoAsistente> periodos;
  final List<String> notas;
  final bool evolucion;
  final bool acumulado;
  const ConsultaAsistente({
    required this.destino,
    required this.tema,
    required this.pregunta,
    required this.periodos,
    this.notas = const [],
    this.evolucion = false,
    this.acumulado = false,
  });
}
