import 'package:app_finnegans/core/theme/colores_reporte_pdf.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/reportes/pdf/estilo_reporte_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Título de una sección, con una bajada opcional que explica cómo leerla.
class TituloSeccionPdf extends pw.StatelessWidget {
  final String titulo;
  final String? bajada;

  TituloSeccionPdf(this.titulo, {this.bajada});

  @override
  pw.Widget build(pw.Context context) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo, style: pw.TextStyle(fontWeight: negrita, fontSize: 12)),
        if (bajada case final bajada?) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            bajada,
            style: const pw.TextStyle(
              fontSize: 8,
              color: ColoresReportePdf.tintaSuave,
            ),
          ),
        ],
      ],
    ),
  );
}

class ChipEstadoPdf extends pw.StatelessWidget {
  final String texto;
  final NivelReporte nivel;
  final bool grande;

  ChipEstadoPdf(this.texto, this.nivel, {this.grande = false});

  @override
  pw.Widget build(pw.Context context) => pw.Container(
    padding: pw.EdgeInsets.symmetric(
      horizontal: grande ? 10 : 6,
      vertical: grande ? 4 : 2,
    ),
    decoration: pw.BoxDecoration(
      color: nivel.fondo,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Text(
      texto,
      style: pw.TextStyle(
        fontWeight: negrita,
        fontSize: grande ? 9 : 7.5,
        color: nivel.color,
      ),
    ),
  );
}

class BarraProgresoPdf extends pw.StatelessWidget {
  final double progreso;
  final PdfColor color;
  final double alto;

  BarraProgresoPdf(this.progreso, this.color, {this.alto = 5});

  @override
  pw.Widget build(pw.Context context) => pw.LayoutBuilder(
    builder: (context, constraints) {
      final ancho = constraints!.maxWidth;
      pw.Widget tramo(double ancho, PdfColor color) => pw.Container(
        width: ancho,
        height: alto,
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(alto / 2),
        ),
      );
      return pw.Stack(
        children: [
          tramo(ancho, ColoresReportePdf.pista),
          tramo(ancho * progreso.clamp(0.0, 1.0), color),
        ],
      );
    },
  );
}

/// Círculo de color de las leyendas.
class PuntoColorPdf extends pw.StatelessWidget {
  final PdfColor color;

  PuntoColorPdf(this.color);

  @override
  pw.Widget build(pw.Context context) => pw.Container(
    width: 7,
    height: 7,
    decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
  );
}

/// Tabla con encabezado repetido en cada página y filas alternadas.
///
/// Es una función y no un `pw.StatelessWidget` porque `MultiPage` decide si
/// puede partir un widget antes de maquetarlo, y un StatelessWidget recién
/// sabe qué contiene al maquetarse: la `pw.Table` tiene que llegar directa.
pw.Table tablaPdf({
  required List<double> anchos,
  required Set<int> derecha,
  required List<String> encabezados,
  required List<List<pw.Widget>> filas,
}) {
  pw.Widget alinear(int columna, pw.Widget hijo) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 5),
    alignment: derecha.contains(columna)
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft,
    child: hijo,
  );

  return pw.Table(
    columnWidths: {
      for (final (i, ancho) in anchos.indexed) i: pw.FlexColumnWidth(ancho),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    tableWidth: pw.TableWidth.max,
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(
        color: ColoresReportePdf.linea,
        width: 0.6,
      ),
      bottom: pw.BorderSide(color: ColoresReportePdf.linea, width: 0.6),
    ),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: ColoresReportePdf.tinta, width: 0.8),
          ),
        ),
        children: [
          for (final (i, texto) in encabezados.indexed)
            alinear(
              i,
              pw.Text(
                texto,
                style: pw.TextStyle(
                  fontWeight: negrita,
                  fontSize: 6.5,
                  letterSpacing: 0.3,
                  color: ColoresReportePdf.tintaSuave,
                ),
              ),
            ),
        ],
      ),
      for (final (n, fila) in filas.indexed)
        pw.TableRow(
          decoration: n.isOdd
              ? const pw.BoxDecoration(color: ColoresReportePdf.fondoSuave)
              : null,
          children: [for (final (i, celda) in fila.indexed) alinear(i, celda)],
        ),
    ],
  );
}
