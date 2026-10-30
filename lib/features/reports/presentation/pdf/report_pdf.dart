import 'dart:typed_data';

import 'package:app_finnegans/core/theme/pdf_report_colors.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_headers.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_report_style.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_summary_sections.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_table_sections.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Maqueta el reporte en A4. La impresión la hace `ImpresionRepository`.
Future<Uint8List> generateReportPdf(TrainingReport report) async {
  final style = await PdfReportStyle.load();
  final doc = pw.Document(
    title: '${report.type.label} · ${report.title}',
    author: 'Finnegans · Formación interna',
  );
  final generated = DateTime.now();
  // Una instancia por posición: los widgets del PDF guardan su maquetado.
  pw.Widget spacing() => pw.SizedBox(height: 18);

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
        theme: pw.ThemeData.withFont(base: style.regular, bold: style.bold)
            .copyWith(
              defaultTextStyle: const pw.TextStyle(
                fontSize: 9,
                color: PdfReportColors.ink,
              ),
            ),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : PdfShortHeader(report, style),
      footer: (context) =>
          PdfFooter(page: context.pageNumber, pages: context.pagesCount),
      // Los bloques cortos no se parten entre páginas; las tablas largas sí,
      // repitiendo su encabezado.
      build: (context) => [
        PdfCover(report, style, generated: generated),
        pw.SizedBox(height: 16),
        pw.Inseparable(child: KpisPdf(report)),
        spacing(),
        pw.Inseparable(child: PdfPeopleStatus(report)),
        spacing(),
        pw.Inseparable(child: PdfCategories(report)),
        spacing(),
        pw.Inseparable(child: PdfSources(report)),
        if (report.evolution.isNotEmpty) ...[
          spacing(),
          pw.Inseparable(child: PdfEvolution(report)),
        ],
        if (report.breakdown.isNotEmpty) ...[
          spacing(),
          ...breakdownPdf(report, style),
        ],
        spacing(),
        ...pdfMembers(report, style),
        pw.SizedBox(height: 14),
        pw.Inseparable(child: PdfNotes()),
      ],
    ),
  );
  return doc.save();
}
