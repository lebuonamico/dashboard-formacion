import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter_test/flutter_test.dart';

const _negocio = TipoCurso.habilidadesDeNegocio;
const _blandas = TipoCurso.habilidadesBlandas;
const _libres = TipoCurso.libresExploracion;

/// Requiere 4 h de Negocio y 4 de Blandas, nada de Libres ni Dictado.
CumplimientoEmpleado _miembro(
  String nombre, {
  double negocio = 0,
  double blandas = 0,
  double libres = 0,
}) {
  final partes = nombre.split(' ');
  return CumplimientoEmpleado(
    empleado: Empleado(
      legajo: nombre,
      nombre: partes.first,
      apellido: partes.last,
      seniority: Seniority.junior1,
      area: 'Desarrollo',
      mail: '${partes.first}@example.com',
      equipo: 'Core',
    ),
    horasValidas: {_negocio: negocio, _blandas: blandas, _libres: libres},
    horasDeclaradas: const {},
    horasRequeridas: const {
      _negocio: 4,
      _blandas: 4,
      _libres: 0,
      TipoCurso.dictadoCapacitaciones: 0,
    },
  );
}

ReporteFormacion _reporte(
  List<CumplimientoEmpleado> miembros, {
  TipoReporte tipo = TipoReporte.area,
  List<FilaDesgloseReporte> desglose = const [],
  String titulo = 'Desarrollo',
  String periodo = 'Octubre 2026',
}) => ReporteFormacion(
  tipo: tipo,
  titulo: titulo,
  periodo: periodo,
  integrantes: miembros.length,
  enObjetivo: 0,
  horas: 0,
  objetivo: 0,
  porcentaje: 0,
  estado: 'Crítico',
  nivel: NivelReporte.critico,
  miembros: miembros,
  desglose: desglose,
);

FilaDesgloseReporte _fila(String nombre, double porcentaje) =>
    FilaDesgloseReporte(
      nombre: nombre,
      integrantes: 1,
      horas: 0,
      objetivo: 0,
      porcentaje: porcentaje,
      estado: '',
      nivel: NivelReporte.desdePorcentaje(porcentaje),
    );

void main() {
  test('El semáforo corta en 100 y 70', () {
    expect(NivelReporte.desdePorcentaje(100), NivelReporte.ok);
    expect(NivelReporte.desdePorcentaje(99.9), NivelReporte.atencion);
    expect(NivelReporte.desdePorcentaje(70), NivelReporte.atencion);
    expect(NivelReporte.desdePorcentaje(69.9), NivelReporte.critico);
  });

  test('Cuenta a cada persona en su nivel, con los tres niveles siempre', () {
    final reporte = _reporte([
      _miembro('Ana Pérez', negocio: 4, blandas: 4), // 100 %
      _miembro('Bruno Gómez', negocio: 4, blandas: 2), // 75 %
      _miembro('Carla Núñez', negocio: 1), // 12.5 %
    ]);

    expect(reporte.conteoPorNivel, {
      NivelReporte.ok: 1,
      NivelReporte.atencion: 1,
      NivelReporte.critico: 1,
    });
    expect(_reporte(const []).conteoPorNivel.values, everyElement(0));
  });

  test('Las horas por categoría se topean al objetivo de cada persona', () {
    final reporte = _reporte([
      // 6 h de Negocio con 4 requeridas: suma 4. Libres no es requerida.
      _miembro('Ana Pérez', negocio: 6, libres: 3),
      _miembro('Bruno Gómez', negocio: 1),
    ]);
    final porTipo = {for (final c in reporte.horasPorCategoria) c.tipo: c};

    expect(reporte.horasPorCategoria.map((c) => c.tipo), TipoCurso.values);
    expect(porTipo[_negocio]!.validas, 5);
    expect(porTipo[_negocio]!.objetivo, 8);
    expect(porTipo[_libres]!.validas, 0);
    expect(porTipo[_libres]!.objetivo, 0);
  });

  test('Lista de menor a mayor cumplimiento y por nombre si empatan', () {
    final reporte = _reporte([
      _miembro('Ana Pérez', negocio: 4, blandas: 4),
      _miembro('Diego Ruiz'),
      _miembro('Bruno Gómez'),
      _miembro('Carla Núñez', negocio: 4, blandas: 2),
    ]);

    expect(reporte.integrantesListados.map((m) => m.empleado.nombre), [
      'Bruno',
      'Diego',
      'Carla',
      'Ana',
    ]);
  });

  test('El general lista solo a los críticos', () {
    final miembros = [
      _miembro('Ana Pérez', negocio: 4, blandas: 4),
      _miembro('Bruno Gómez', negocio: 4, blandas: 2),
      _miembro('Carla Núñez', negocio: 1),
    ];

    final general = _reporte(miembros, tipo: TipoReporte.general);
    expect(general.soloCriticos, isTrue);
    expect(general.integrantesListados.map((m) => m.empleado.nombre), [
      'Carla',
    ]);
    expect(_reporte(miembros).integrantesListados, hasLength(3));
  });

  test('El tipo decide el desglose y la ubicación de cada integrante', () {
    expect(TipoReporte.general.tituloDesglose, 'Cumplimiento por área');
    expect(TipoReporte.area.tituloDesglose, 'Cumplimiento por equipo');
    expect(TipoReporte.equipo.tituloDesglose, isNull);

    expect(
      _reporte(const [], tipo: TipoReporte.general).ubicacionIntegrante,
      UbicacionIntegrante.areaYEquipo,
    );
    expect(_reporte(const []).ubicacionIntegrante, UbicacionIntegrante.equipo);
    expect(
      _reporte(const [], tipo: TipoReporte.equipo).ubicacionIntegrante,
      UbicacionIntegrante.ninguna,
    );
  });

  test('El desglose va de menor a mayor cumplimiento', () {
    final reporte = _reporte(
      const [],
      desglose: [_fila('Core', 80), _fila('Mobile', 40), _fila('Web', 100)],
    );

    expect(reporte.desgloseOrdenado.map((f) => f.nombre), [
      'Mobile',
      'Core',
      'Web',
    ]);
    expect(reporte.desglose.first.nombre, 'Core');
  });

  test('El nombre del archivo no lleva tildes, eñes ni símbolos', () {
    final reporte = _reporte(
      const [],
      titulo: 'Diseño & Núñez',
      periodo: 'Año 2026 · meses con datos',
    );

    expect(
      reporte.nombreArchivo,
      'reporte_de_area_diseno_nunez_ano_2026_meses_con_datos.pdf',
    );
  });
}
