import 'dart:io';

import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/reportes/reporte_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

CumplimientoEmpleado _miembro(
  int legajo,
  String nombre,
  String equipo,
  Seniority seniority,
  List<double> validas,
  List<double> declaradas,
) {
  final requeridas = {
    TipoCurso.habilidadesDeNegocio: seniority.negocio,
    TipoCurso.habilidadesBlandas: seniority.blandas,
    TipoCurso.libresExploracion: seniority.libres,
    TipoCurso.dictadoCapacitaciones: seniority.dictado,
  };
  final partes = nombre.split(' ');
  return CumplimientoEmpleado(
    empleado: Empleado(
      legajo: '$legajo',
      nombre: partes.first,
      apellido: partes.last,
      seniority: seniority,
      area: 'Desarrollo',
      mail: '$legajo@example.com',
      equipo: equipo,
    ),
    horasValidas: {
      for (final (i, tipo) in TipoCurso.values.indexed) tipo: validas[i],
    },
    horasDeclaradas: {
      for (final (i, tipo) in TipoCurso.values.indexed) tipo: declaradas[i],
    },
    horasRequeridas: requeridas,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final miembros = [
    _miembro(
      101,
      'Ana Pérez',
      'Core',
      Seniority.junior2,
      [6, 4, 0, 0],
      [3, 4, 0, 0],
    ),
    _miembro(
      102,
      'Bruno Gómez',
      'Core',
      Seniority.semisenior2,
      [2, 1, 0, 0],
      [2, 1, 0, 0],
    ),
    _miembro(
      103,
      'Carla Núñez',
      'Mobile',
      Seniority.senior1,
      [0, 2, 2, 4],
      [0, 2, 2, 4],
    ),
    _miembro(
      104,
      'Diego Ruiz',
      'Mobile',
      Seniority.trainee,
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ),
  ];

  ReporteFormacion reporte({bool soloCriticos = false}) => ReporteFormacion(
    tipo: 'Reporte de área',
    titulo: 'Desarrollo',
    detalles: const ['Líder: María López', '2 equipos'],
    periodo: 'Octubre 2026',
    integrantes: 4,
    enObjetivo: 2,
    horas: 21,
    objetivo: 34,
    porcentaje: 61.8,
    estado: 'Crítico',
    nivel: NivelReporte.critico,
    miembros: miembros,
    desgloseTitulo: 'Cumplimiento por equipo',
    desglose: const [
      FilaDesgloseReporte(
        nombre: 'Core',
        integrantes: 2,
        horas: 11,
        objetivo: 16,
        porcentaje: 68.8,
        estado: 'Crítico',
        nivel: NivelReporte.critico,
      ),
      FilaDesgloseReporte(
        nombre: 'Mobile',
        integrantes: 2,
        horas: 10,
        objetivo: 18,
        porcentaje: 55.6,
        estado: 'En riesgo',
        nivel: NivelReporte.atencion,
      ),
    ],
    evolucion: [
      (mes: DateTime(2026, 7), horas: 3.2),
      (mes: DateTime(2026, 8), horas: 4.1),
      (mes: DateTime(2026, 9), horas: 2.7),
      (mes: DateTime(2026, 10), horas: 5.3),
    ],
    soloCriticos: soloCriticos,
    mostrarEquipo: !soloCriticos,
  );

  test('genera el PDF del reporte con tildes y varias secciones', () async {
    final bytes = await generarReportePdf(reporte());
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    // Para revisar el diseño a mano: REPORTE_PDF_SALIDA=<carpeta>.
    final salida = Platform.environment['REPORTE_PDF_SALIDA'];
    if (salida != null) {
      File('$salida/reporte_area.pdf').writeAsBytesSync(bytes);
      File(
        '$salida/reporte_general.pdf',
      ).writeAsBytesSync(await generarReportePdf(reporte(soloCriticos: true)));
    }
  });

  test('el nombre del archivo no lleva tildes ni espacios', () {
    expect(
      reporte().nombreArchivo,
      'reporte_de_area_desarrollo_octubre_2026.pdf',
    );
  });
}
