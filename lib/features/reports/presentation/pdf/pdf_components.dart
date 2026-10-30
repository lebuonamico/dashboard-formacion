import 'package:app_finnegans/core/theme/pdf_report_colors.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_report_style.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Título de una sección, con una bajada opcional que explica cómo leerla.
class PdfSectionTitle extends pw.StatelessWidget {
  final String title;
  final String? lowered;

  PdfSectionTitle(this.title, {this.lowered});

  @override
  pw.Widget build(pw.Context context) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: bold, fontSize: 12)),
        if (lowered case final lowered?) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            lowered,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfReportColors.softInk,
            ),
          ),
        ],
      ],
    ),
  );
}

class PdfStatusChip extends pw.StatelessWidget {
  final String text;
  final ReportLevel level;
  final bool large;

  PdfStatusChip(this.text, this.level, {this.large = false});

  @override
  pw.Widget build(pw.Context context) => pw.Container(
    padding: pw.EdgeInsets.symmetric(
      horizontal: large ? 10 : 6,
      vertical: large ? 4 : 2,
    ),
    decoration: pw.BoxDecoration(
      color: level.background,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: bold,
        fontSize: large ? 9 : 7.5,
        color: level.color,
      ),
    ),
  );
}

class PdfProgressBar extends pw.StatelessWidget {
  final double progress;
  final PdfColor color;
  final double height;

  PdfProgressBar(this.progress, this.color, {this.height = 5});

  @override
  pw.Widget build(pw.Context context) => pw.LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints!.maxWidth;
      pw.Widget segment(double columnWidth, PdfColor color) => pw.Container(
        width: columnWidth,
        height: height,
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(height / 2),
        ),
      );
      return pw.Stack(
        children: [
          segment(width, PdfReportColors.track),
          segment(width * progress.clamp(0.0, 1.0), color),
        ],
      );
    },
  );
}

/// Círculo de color de las leyendas.
class PdfColorDot extends pw.StatelessWidget {
  final PdfColor color;

  PdfColorDot(this.color);

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
pw.Table pdfTable({
  required List<double> widths,
  required Set<int> right,
  required List<String> headers,
  required List<List<pw.Widget>> rows,
}) {
  pw.Widget align(int column, pw.Widget child) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 5),
    alignment: right.contains(column)
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft,
    child: child,
  );

  return pw.Table(
    columnWidths: {
      for (final (i, width) in widths.indexed) i: pw.FlexColumnWidth(width),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    tableWidth: pw.TableWidth.max,
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfReportColors.line, width: 0.6),
      bottom: pw.BorderSide(color: PdfReportColors.line, width: 0.6),
    ),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfReportColors.ink, width: 0.8),
          ),
        ),
        children: [
          for (final (i, text) in headers.indexed)
            align(
              i,
              pw.Text(
                text,
                style: pw.TextStyle(
                  fontWeight: bold,
                  fontSize: 6.5,
                  letterSpacing: 0.3,
                  color: PdfReportColors.softInk,
                ),
              ),
            ),
        ],
      ),
      for (final (n, row) in rows.indexed)
        pw.TableRow(
          decoration: n.isOdd
              ? const pw.BoxDecoration(color: PdfReportColors.softBackground)
              : null,
          children: [for (final (i, cell) in row.indexed) align(i, cell)],
        ),
    ],
  );
}
