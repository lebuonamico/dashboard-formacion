import 'package:app_finnegans/domain/modelos/comparacion_moodle_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';

/// Qué sección de la app resume el reporte.
enum TipoReporte {
  general('Reporte general', tituloDesglose: 'Cumplimiento por área'),
  area('Reporte de área', tituloDesglose: 'Cumplimiento por equipo'),
  equipo('Reporte de equipo');

  final String label;

  /// Título de la tabla de desglose; `null` si el reporte no tiene desglose.
  final String? tituloDesglose;

  const TipoReporte(this.label, {this.tituloDesglose});
}

/// Semáforo de una fila del reporte, ya resuelto por quien lo arma.
enum NivelReporte {
  ok,
  atencion,
  critico;

  /// Mismos cortes que el semáforo de la app.
  static NivelReporte desdePorcentaje(double porcentaje) => porcentaje >= 100
      ? NivelReporte.ok
      : porcentaje >= 70
      ? NivelReporte.atencion
      : NivelReporte.critico;
}

/// Qué dato de ubicación acompaña a cada integrante en la tabla.
enum UbicacionIntegrante { ninguna, equipo, areaYEquipo }

typedef HorasCategoriaReporte = ({
  TipoCurso tipo,
  double validas,
  double objetivo,
});

/// Una fila del desglose: áreas en el general, equipos en el de área.
class FilaDesgloseReporte {
  final String nombre;
  final int integrantes;
  final double horas;
  final double objetivo;
  final double porcentaje;
  final String estado;
  final NivelReporte nivel;

  const FilaDesgloseReporte({
    required this.nombre,
    required this.integrantes,
    required this.horas,
    required this.objetivo,
    required this.porcentaje,
    required this.estado,
    required this.nivel,
  });
}

/// Todo lo que muestra el reporte, con los mismos números que la pantalla.
class ReporteFormacion {
  final TipoReporte tipo;
  final String titulo;

  /// Líneas cortas bajo el título: área, líder, etc.
  final List<String> detalles;
  final String periodo;

  final int integrantes;
  final int enObjetivo;
  final double horas;
  final double objetivo;
  final double porcentaje;
  final String estado;
  final NivelReporte nivel;

  final ProyeccionAnual? proyeccion;
  final List<CumplimientoEmpleado> miembros;
  final List<FilaDesgloseReporte> desglose;

  /// Horas válidas por persona de los últimos meses (solo el general).
  final List<({DateTime mes, double horas})> evolucion;

  const ReporteFormacion({
    required this.tipo,
    required this.titulo,
    this.detalles = const [],
    required this.periodo,
    required this.integrantes,
    required this.enObjetivo,
    required this.horas,
    required this.objetivo,
    required this.porcentaje,
    required this.estado,
    required this.nivel,
    this.proyeccion,
    required this.miembros,
    this.desglose = const [],
    this.evolucion = const [],
  });

  /// En el general la nómina es larga: se listan solo los críticos.
  bool get soloCriticos => tipo == TipoReporte.general;

  UbicacionIntegrante get ubicacionIntegrante => switch (tipo) {
    TipoReporte.general => UbicacionIntegrante.areaYEquipo,
    TipoReporte.area => UbicacionIntegrante.equipo,
    TipoReporte.equipo => UbicacionIntegrante.ninguna,
  };

  String get nombreArchivo {
    final base = '${tipo.label} $titulo $periodo'
        .toLowerCase()
        .replaceAll(RegExp(r'[áà]'), 'a')
        .replaceAll(RegExp(r'[éè]'), 'e')
        .replaceAll(RegExp(r'[íì]'), 'i')
        .replaceAll(RegExp(r'[óò]'), 'o')
        .replaceAll(RegExp(r'[úù]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '$base.pdf';
  }

  /// Cuántas personas evaluadas caen en cada nivel del semáforo.
  Map<NivelReporte, int> get conteoPorNivel {
    final conteo = {for (final nivel in NivelReporte.values) nivel: 0};
    for (final miembro in miembros) {
      final nivel = NivelReporte.desdePorcentaje(miembro.porcentajeTotal);
      conteo[nivel] = conteo[nivel]! + 1;
    }
    return conteo;
  }

  /// Cada persona suma hasta su objetivo en cada categoría, y nada en las que
  /// su seniority no pide: son las horas que cuentan para la meta.
  List<HorasCategoriaReporte> get horasPorCategoria {
    double suma(double Function(CumplimientoEmpleado) valor) =>
        miembros.fold(0, (t, m) => t + valor(m));
    return [
      for (final tipo in TipoCurso.values)
        (
          tipo: tipo,
          validas: suma((m) => m.horasAplicablesAlObjetivo(tipo)),
          objetivo: suma((m) => m.horasRequeridas[tipo] ?? 0),
        ),
    ];
  }

  ComparacionMoodleCrm get comparacionFuentes =>
      ComparacionMoodleCrm.desde(miembros);

  /// De menor a mayor cumplimiento, y por nombre a igual porcentaje.
  List<CumplimientoEmpleado> get integrantesListados {
    final ordenados = [...miembros]
      ..sort((a, b) {
        final porcentaje = a.porcentajeTotal.compareTo(b.porcentajeTotal);
        return porcentaje != 0
            ? porcentaje
            : a.empleado.nombreCompleto.compareTo(b.empleado.nombreCompleto);
      });
    if (!soloCriticos) return ordenados;
    return [
      for (final m in ordenados)
        if (NivelReporte.desdePorcentaje(m.porcentajeTotal) ==
            NivelReporte.critico)
          m,
    ];
  }

  /// De menor a mayor cumplimiento: lo que peor está, primero.
  List<FilaDesgloseReporte> get desgloseOrdenado =>
      [...desglose]..sort((a, b) => a.porcentaje.compareTo(b.porcentaje));
}
