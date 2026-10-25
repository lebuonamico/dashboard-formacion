import 'package:app_finnegans/core/theme/colores_reporte_pdf.dart';
import 'package:app_finnegans/domain/modelos/comparacion_moodle_crm.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:app_finnegans/presentation/reportes/pdf/componentes_pdf.dart';
import 'package:app_finnegans/presentation/reportes/pdf/estilo_reporte_pdf.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Las mismas tarjetas que la pantalla: integrantes, horas, cumplimiento y,
/// si hay, la proyección a diciembre.
class KpisPdf extends pw.StatelessWidget {
  final ReporteFormacion reporte;

  KpisPdf(this.reporte);

  @override
  pw.Widget build(pw.Context context) {
    final r = reporte;
    final faltan = (r.objetivo - r.horas).clamp(0.0, double.infinity);
    final tarjetas = [
      _TarjetaKpiPdf(
        titulo: 'INTEGRANTES',
        valor: '${r.integrantes}',
        detalle: '${r.enObjetivo} en objetivo',
        progreso: r.integrantes == 0 ? 0 : r.enObjetivo / r.integrantes,
        color: ColoresReportePdf.marca,
      ),
      _TarjetaKpiPdf(
        titulo: 'HORAS VÁLIDAS',
        valor: horasPdf(r.horas),
        detalle:
            'de ${horasEnterasPdf(r.objetivo)} · faltan ${horasPdf(faltan)}',
        progreso: r.objetivo == 0 ? 0 : r.horas / r.objetivo,
        color: ColoresReportePdf.marca,
      ),
      _TarjetaKpiPdf(
        titulo: 'CUMPLIMIENTO',
        valor: formatearPorcentaje(r.porcentaje),
        detalle: r.estado,
        progreso: r.porcentaje / 100,
        color: r.nivel.color,
        colorValor: r.nivel.color,
      ),
      if (r.proyeccion case final p?)
        _TarjetaKpiPdf(
          titulo: 'PROYECCIÓN A DIC.',
          valor: formatearPorcentaje(p.porcentaje),
          detalle:
              '${p.estado.label} · ${p.llegan} de ${p.colaboradores} llegan',
          progreso: p.porcentaje / 100,
          color: switch (p.estado) {
            EstadoProyeccion.enCamino => NivelReporte.ok.color,
            EstadoProyeccion.alcanzable => NivelReporte.atencion.color,
            EstadoProyeccion.enRiesgo => NivelReporte.critico.color,
          },
        ),
    ];
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (i, tarjeta) in tarjetas.indexed) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(child: tarjeta),
        ],
      ],
    );
  }
}

class _TarjetaKpiPdf extends pw.StatelessWidget {
  final String titulo;
  final String valor;
  final String detalle;
  final double progreso;
  final PdfColor color;
  final PdfColor? colorValor;

  _TarjetaKpiPdf({
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.progreso,
    required this.color,
    this.colorValor,
  });

  @override
  pw.Widget build(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 10),
    decoration: pw.BoxDecoration(
      color: ColoresReportePdf.fondoSuave,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: ColoresReportePdf.linea),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo,
          style: pw.TextStyle(
            fontWeight: negrita,
            fontSize: 6.5,
            letterSpacing: 0.6,
            color: ColoresReportePdf.tintaSuave,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          valor,
          style: pw.TextStyle(
            fontWeight: negrita,
            fontSize: 17,
            color: colorValor ?? ColoresReportePdf.tinta,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          detalle,
          maxLines: 1,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: ColoresReportePdf.tintaSuave,
          ),
        ),
        pw.SizedBox(height: 6),
        BarraProgresoPdf(progreso, color, alto: 4),
      ],
    ),
  );
}

/// Cómo se reparten las personas evaluadas en el semáforo.
class EstadoPersonasPdf extends pw.StatelessWidget {
  final ReporteFormacion reporte;

  EstadoPersonasPdf(this.reporte);

  static const _etiquetas = {
    NivelReporte.ok: 'Cumple (100%)',
    NivelReporte.atencion: 'Atención (70 a 99%)',
    NivelReporte.critico: 'No cumple (menos de 70%)',
  };

  @override
  pw.Widget build(pw.Context context) {
    final conteo = reporte.conteoPorNivel;
    final total = reporte.miembros.length;
    int porcentaje(NivelReporte nivel) =>
        total == 0 ? 0 : (conteo[nivel]! / total * 100).round();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        TituloSeccionPdf(
          'Estado de cumplimiento',
          bajada:
              'Cómo se reparten las $total personas evaluadas en el semáforo',
        ),
        // Barra apilada: una lectura rápida de la proporción.
        pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Row(
            children: [
              for (final nivel in NivelReporte.values)
                if (conteo[nivel]! > 0)
                  pw.Expanded(
                    flex: conteo[nivel]!,
                    child: pw.Container(
                      height: 14,
                      color: nivel.color,
                      alignment: pw.Alignment.center,
                      child: conteo[nivel]! / total >= 0.08
                          ? pw.Text(
                              '${porcentaje(nivel)}%',
                              style: pw.TextStyle(
                                fontWeight: negrita,
                                fontSize: 7,
                                color: ColoresReportePdf.blanco,
                              ),
                            )
                          : null,
                    ),
                  ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            for (final nivel in NivelReporte.values) ...[
              PuntoColorPdf(nivel.color),
              pw.SizedBox(width: 4),
              pw.Text(
                _etiquetas[nivel]!,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                '${conteo[nivel]} (${porcentaje(nivel)}%)',
                style: pw.TextStyle(fontWeight: negrita, fontSize: 8),
              ),
              pw.SizedBox(width: 16),
            ],
          ],
        ),
      ],
    );
  }
}

/// Horas válidas contra objetivo en cada categoría, con una fila de total.
class CategoriasPdf extends pw.StatelessWidget {
  final ReporteFormacion reporte;

  CategoriasPdf(this.reporte);

  @override
  pw.Widget build(pw.Context context) {
    final categorias = reporte.horasPorCategoria;
    final totalValidas = categorias.fold<double>(0, (t, c) => t + c.validas);
    final totalObjetivo = categorias.fold<double>(0, (t, c) => t + c.objetivo);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        TituloSeccionPdf(
          'Horas por categoría',
          bajada:
              'Horas válidas para la meta: cada persona suma hasta su objetivo en cada categoría.',
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: ColoresReportePdf.tinta, width: 0.8),
            ),
          ),
          child: pw.Row(
            children: [
              _encabezado('CATEGORÍA', ancho: 150),
              _encabezado('VÁLIDAS', ancho: 70, derecha: true),
              _encabezado('OBJETIVO', ancho: 70, derecha: true),
              pw.SizedBox(width: 16),
              _encabezado('AVANCE'),
              _encabezado('%', ancho: 40, derecha: true),
            ],
          ),
        ),
        for (final c in categorias)
          _fila(
            nombre: pw.Row(
              children: [
                PuntoColorPdf(ColoresReportePdf.categoria[c.tipo]!),
                pw.SizedBox(width: 6),
                pw.Text(c.tipo.label, style: const pw.TextStyle(fontSize: 8.5)),
              ],
            ),
            validas: c.validas,
            objetivo: c.objetivo,
            color: ColoresReportePdf.categoria[c.tipo]!,
          ),
        _fila(
          nombre: pw.Text(
            'Total',
            style: pw.TextStyle(fontWeight: negrita, fontSize: 8.5),
          ),
          validas: totalValidas,
          objetivo: totalObjetivo,
          color: ColoresReportePdf.tinta,
          total: true,
        ),
      ],
    );
  }

  pw.Widget _encabezado(String texto, {double? ancho, bool derecha = false}) {
    final t = pw.Text(
      texto,
      textAlign: derecha ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontWeight: negrita,
        fontSize: 7,
        color: ColoresReportePdf.tintaSuave,
      ),
    );
    return ancho == null
        ? pw.Expanded(child: t)
        : pw.SizedBox(width: ancho, child: t);
  }

  pw.Widget _fila({
    required pw.Widget nombre,
    required double validas,
    required double objetivo,
    required PdfColor color,
    bool total = false,
  }) {
    final progreso = objetivo == 0 ? 1.0 : validas / objetivo;
    final estilo = pw.TextStyle(
      fontWeight: total ? negrita : null,
      fontSize: 8.5,
    );
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: total ? ColoresReportePdf.fondoSuave : null,
        border: const pw.Border(
          bottom: pw.BorderSide(color: ColoresReportePdf.linea),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 150, child: nombre),
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              horasPdf(validas),
              style: estilo,
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              horasPdf(objetivo),
              style: estilo.copyWith(color: ColoresReportePdf.tintaSuave),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(child: BarraProgresoPdf(progreso, color)),
          pw.SizedBox(
            width: 40,
            child: pw.Text(
              objetivo == 0 ? '-' : formatearPorcentaje(progreso * 100),
              style: estilo.copyWith(fontWeight: negrita),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horas de cada fuente sin tope, y cuánto difieren donde las dos existen.
class FuentesPdf extends pw.StatelessWidget {
  final ReporteFormacion reporte;

  FuentesPdf(this.reporte);

  @override
  pw.Widget build(pw.Context context) {
    final c = reporte.comparacionFuentes;
    const comparables = ComparacionMoodleCrm.comparables;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        TituloSeccionPdf(
          'Moodle vs CRM',
          bajada:
              'Horas registradas en cada fuente, sin tope. Libres y Dictado solo existen en CRM.',
        ),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(2.2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: ColoresReportePdf.linea),
            bottom: pw.BorderSide(color: ColoresReportePdf.linea),
          ),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: ColoresReportePdf.tinta,
                    width: 0.8,
                  ),
                ),
              ),
              children: [
                _encabezado('CATEGORÍA', derecha: false),
                _encabezado('MOODLE (LMS)'),
                _encabezado('CRM'),
                _encabezado('DIFERENCIA'),
              ],
            ),
            for (final tipo in TipoCurso.values)
              pw.TableRow(
                children: [
                  _nombre(tipo.label),
                  comparables.contains(tipo)
                      ? _celda(horasPdf(c.moodle[tipo] ?? 0))
                      : _celda('-', color: ColoresReportePdf.tintaSuave),
                  _celda(horasPdf(c.crm[tipo] ?? 0)),
                  _celda(
                    comparables.contains(tipo)
                        ? diferenciaHorasPdf(
                            (c.crm[tipo] ?? 0) - (c.moodle[tipo] ?? 0),
                          )
                        : '-',
                    color: ColoresReportePdf.tintaSuave,
                  ),
                ],
              ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: ColoresReportePdf.fondoSuave,
              ),
              children: [
                _nombre('Total', resaltado: true),
                _celda(horasPdf(c.totalMoodle(comparables)), resaltado: true),
                _celda(horasPdf(c.totalCrm(TipoCurso.values)), resaltado: true),
                _celda(''),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: ColoresReportePdf.marcaFondo,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            _textoDiferencia(c),
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    );
  }

  static String _textoDiferencia(ComparacionMoodleCrm c) {
    if (c.coinciden) return 'En Negocio y Blandas las dos fuentes coinciden.';
    final diferencia = c.diferenciaComparable;
    final signo = diferencia > 0 ? '+' : '-';
    final porcentaje = switch (c.diferenciaPorcentual) {
      final p? => ' ($signo${p.abs().toStringAsFixed(0)}%)',
      null => '',
    };
    return 'En Negocio y Blandas, CRM registra ${horasPdf(diferencia.abs())} '
        '${diferencia > 0 ? 'más' : 'menos'} que Moodle$porcentaje.';
  }

  static const _padding = pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8);

  pw.Widget _celda(String texto, {bool resaltado = false, PdfColor? color}) =>
      pw.Padding(
        padding: _padding,
        child: pw.Text(
          texto,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontWeight: resaltado ? negrita : null,
            fontSize: 8.5,
            color: color,
          ),
        ),
      );

  pw.Widget _nombre(String texto, {bool resaltado = false}) => pw.Padding(
    padding: _padding,
    child: pw.Text(
      texto,
      style: pw.TextStyle(
        fontWeight: resaltado ? negrita : null,
        fontSize: 8.5,
      ),
    ),
  );

  pw.Widget _encabezado(String texto, {bool derecha = true}) => pw.Padding(
    padding: _padding,
    child: pw.Text(
      texto,
      textAlign: derecha ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontWeight: negrita,
        fontSize: 7,
        color: ColoresReportePdf.tintaSuave,
      ),
    ),
  );
}

/// Horas válidas promedio por colaborador de los últimos meses.
class EvolucionPdf extends pw.StatelessWidget {
  final ReporteFormacion reporte;

  EvolucionPdf(this.reporte);

  static const _alto = 70.0;

  @override
  pw.Widget build(pw.Context context) {
    final evolucion = reporte.evolucion;
    final maximo = evolucion.fold<double>(
      0,
      (m, punto) => punto.horas > m ? punto.horas : m,
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        TituloSeccionPdf(
          'Evolución mensual',
          bajada: 'Horas válidas promedio por colaborador en los últimos meses',
        ),
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: pw.BoxDecoration(
            color: ColoresReportePdf.fondoSuave,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: ColoresReportePdf.linea),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (final (i, punto) in evolucion.indexed)
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        horasPdf(punto.horas),
                        style: pw.TextStyle(fontWeight: negrita, fontSize: 8),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        width: 36,
                        height: maximo == 0
                            ? 1
                            : (_alto * punto.horas / maximo).clamp(1.0, _alto),
                        decoration: pw.BoxDecoration(
                          // El último mes es el del período elegido.
                          color: i == evolucion.length - 1
                              ? ColoresReportePdf.marca
                              : ColoresReportePdf.pista,
                          borderRadius: const pw.BorderRadius.vertical(
                            top: pw.Radius.circular(3),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${nombreMes(punto.mes.month)} ${punto.mes.year}',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: ColoresReportePdf.tintaSuave,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
