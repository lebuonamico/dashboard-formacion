import 'package:app_finnegans/core/theme/pdf_report_colors.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_components.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_report_style.dart';
import 'package:pdf/widgets.dart' as pw;

/// Encabezado de la primera página: marca, tipo, título, estado y período.
class PdfCover extends pw.StatelessWidget {
  final TrainingReport report;
  final PdfReportStyle style;
  final DateTime generated;

  PdfCover(this.report, this.style, {required this.generated});

  @override
  pw.Widget build(pw.Context context) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Image(style.logo, width: 26, height: 26),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            'FINNEGANS · FORMACIÓN INTERNA',
            style: pw.TextStyle(
              fontWeight: bold,
              fontSize: 8,
              letterSpacing: 1.2,
              color: PdfReportColors.softInk,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Generado el ${pdfDateTime(generated)}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfReportColors.softInk,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 18),
      pw.Text(
        report.type.label.toUpperCase(),
        style: pw.TextStyle(
          fontWeight: bold,
          fontSize: 9,
          letterSpacing: 1,
          color: PdfReportColors.brand,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Text(
              report.title,
              style: pw.TextStyle(
                fontWeight: bold,
                fontSize: 22,
                color: PdfReportColors.ink,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          PdfStatusChip(report.status, report.level, large: true),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 14,
        runSpacing: 2,
        children: [
          _data('Período', report.period),
          for (final detail in report.details)
            pw.Text(
              detail,
              style: const pw.TextStyle(
                color: PdfReportColors.softInk,
                fontSize: 9,
              ),
            ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Container(height: 2, color: PdfReportColors.brand),
    ],
  );

  pw.Widget _data(String label, String value) => pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label: ',
          style: const pw.TextStyle(
            color: PdfReportColors.softInk,
            fontSize: 9,
          ),
        ),
        pw.TextSpan(text: value, style: style.mediumText(9)),
      ],
    ),
  );
}

/// Encabezado de las páginas siguientes a la primera.
class PdfShortHeader extends pw.StatelessWidget {
  final TrainingReport report;
  final PdfReportStyle style;

  PdfShortHeader(this.report, this.style);

  @override
  pw.Widget build(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfReportColors.line)),
    ),
    child: pw.Row(
      children: [
        pw.Text(
          '${report.type.label} · ${report.title}',
          style: style.mediumText(8),
        ),
        pw.Spacer(),
        pw.Text(
          report.period,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfReportColors.softInk,
          ),
        ),
      ],
    ),
  );
}

class PdfFooter extends pw.StatelessWidget {
  final int page;
  final int pages;

  PdfFooter({required this.page, required this.pages});

  @override
  pw.Widget build(pw.Context context) {
    const style = pw.TextStyle(fontSize: 7, color: PdfReportColors.softInk);
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        children: [
          pw.Text('Plan de formación interna · uso interno', style: style),
          pw.Spacer(),
          pw.Text('Página $page de $pages', style: style),
        ],
      ),
    );
  }
}
