import 'package:app_finnegans/core/theme/colores_reporte_pdf.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/reportes/pdf/componentes_pdf.dart';
import 'package:app_finnegans/presentation/reportes/pdf/estilo_reporte_pdf.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:pdf/widgets.dart' as pw;

// Las tablas largas devuelven el título y la `pw.Table` por separado para
// que `MultiPage` pueda partir la tabla entre páginas (ver `tablaPdf`).

/// Áreas en el general, equipos en el de área.
List<pw.Widget> desglosePdf(ReporteFormacion reporte, EstiloReportePdf estilo) {
  const estiloCelda = pw.TextStyle(fontSize: 8);
  return [
    TituloSeccionPdf(
      reporte.tipo.tituloDesglose ?? 'Desglose',
      bajada: 'Ordenado de menor a mayor cumplimiento',
    ),
    tablaPdf(
      anchos: const [3, 1.1, 1.8, 1.3, 1.2],
      derecha: const {1, 2, 3},
      encabezados: const [
        'NOMBRE',
        'INTEGRANTES',
        'HORAS / OBJETIVO',
        'CUMPLIMIENTO',
        'ESTADO',
      ],
      filas: [
        for (final f in reporte.desgloseOrdenado)
          [
            pw.Text(f.nombre, style: estilo.textoMedio(8)),
            pw.Text('${f.integrantes}', style: estiloCelda),
            pw.Text(
              '${horasPdf(f.horas)} / ${horasEnterasPdf(f.objetivo)}',
              style: estiloCelda,
            ),
            pw.Text(
              formatearPorcentaje(f.porcentaje),
              style: pw.TextStyle(
                fontWeight: negrita,
                fontSize: 8,
                color: f.nivel.color,
              ),
            ),
            ChipEstadoPdf(f.estado, f.nivel),
          ],
      ],
    ),
  ];
}

/// Integrantes con sus horas por categoría. En el general, solo los críticos.
List<pw.Widget> integrantesPdf(
  ReporteFormacion reporte,
  EstiloReportePdf estilo,
) {
  final lista = reporte.integrantesListados;
  final titulo = reporte.soloCriticos
      ? TituloSeccionPdf(
          'Colaboradores que requieren seguimiento',
          bajada:
              '${lista.length} con menos de 70% de cumplimiento, de menor a mayor. '
              'Por categoría: horas válidas / objetivo.',
        )
      : TituloSeccionPdf(
          'Integrantes (${lista.length})',
          bajada:
              'De menor a mayor cumplimiento. Por categoría: horas válidas / objetivo.',
        );

  if (lista.isEmpty) {
    return [
      titulo,
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: NivelReporte.ok.fondo,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'Nadie está por debajo de 70% de cumplimiento en este período.',
          style: estilo.textoMedio(8.5).copyWith(color: NivelReporte.ok.color),
        ),
      ),
    ];
  }

  final ubicacion = reporte.ubicacionIntegrante;
  final conUbicacion = ubicacion != UbicacionIntegrante.ninguna;
  const estiloCelda = pw.TextStyle(fontSize: 7.5);

  return [
    titulo,
    tablaPdf(
      anchos: [
        2.3,
        if (conUbicacion) 1.5,
        1.4,
        for (final _ in TipoCurso.values) 1.05,
        1.3,
        0.8,
      ],
      // Categorías, horas y %: las columnas numéricas del final.
      derecha: {
        for (var i = 0; i < TipoCurso.values.length + 2; i++)
          i + (conUbicacion ? 3 : 2),
      },
      encabezados: [
        'COLABORADOR',
        if (conUbicacion)
          ubicacion == UbicacionIntegrante.areaYEquipo
              ? 'ÁREA / EQUIPO'
              : 'EQUIPO',
        'SENIORITY',
        for (final tipo in TipoCurso.values) tipo.labelCorto.toUpperCase(),
        'HORAS',
        '%',
      ],
      filas: [
        for (final m in lista)
          [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  m.empleado.nombreCompleto,
                  style: estilo.textoMedio(7.5),
                ),
                pw.Text(
                  'Legajo ${m.empleado.legajo}',
                  style: const pw.TextStyle(
                    fontSize: 6.5,
                    color: ColoresReportePdf.tintaSuave,
                  ),
                ),
              ],
            ),
            if (conUbicacion)
              pw.Text(_ubicacion(m.empleado, ubicacion), style: estiloCelda),
            pw.Text(m.empleado.seniority.label, style: estiloCelda),
            for (final tipo in TipoCurso.values)
              pw.Text(_categoria(m, tipo), style: estiloCelda),
            pw.Text(
              '${m.totalHorasValidas.toStringAsFixed(1)} / '
              '${m.totalHorasRequeridas.toStringAsFixed(0)}',
              style: estiloCelda,
            ),
            pw.Text(
              formatearPorcentaje(m.porcentajeTotal),
              style: pw.TextStyle(
                fontWeight: negrita,
                fontSize: 7.5,
                color: NivelReporte.desdePorcentaje(m.porcentajeTotal).color,
              ),
            ),
          ],
      ],
    ),
  ];
}

String _ubicacion(Empleado empleado, UbicacionIntegrante ubicacion) =>
    switch (ubicacion) {
      UbicacionIntegrante.areaYEquipo => [
        empleado.area,
        empleado.equipo,
      ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' / '),
      UbicacionIntegrante.equipo =>
        empleado.equipo.trim().isEmpty ? 'Sin equipo' : empleado.equipo.trim(),
      UbicacionIntegrante.ninguna => '',
    };

/// Horas válidas / objetivo, o "-" si su seniority no pide esa categoría.
String _categoria(CumplimientoEmpleado m, TipoCurso tipo) {
  final requeridas = m.horasRequeridas[tipo] ?? 0;
  if (requeridas <= 0) return '-';
  return '${m.horasAplicablesAlObjetivo(tipo).toStringAsFixed(1)}/'
      '${requeridas.toStringAsFixed(0)}';
}

class NotasPdf extends pw.StatelessWidget {
  @override
  pw.Widget build(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: ColoresReportePdf.linea),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      'Cómo leer este reporte. Horas válidas: las que suman a la meta. '
      'Negocio y Blandas se acreditan con los cursos finalizados en Moodle; '
      'Libres y Dictado, con lo declarado en CRM. Cada persona suma como máximo '
      'su objetivo en cada categoría, según su seniority. El semáforo usa los '
      'cortes 100% (cumple) y 70% (atención).',
      style: const pw.TextStyle(
        fontSize: 7,
        color: ColoresReportePdf.tintaSuave,
        lineSpacing: 2,
      ),
    ),
  );
}
