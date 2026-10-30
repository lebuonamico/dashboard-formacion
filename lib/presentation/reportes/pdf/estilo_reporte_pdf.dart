import 'package:app_finnegans/core/theme/colores_reporte_pdf.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fuentes y logo del reporte. La regular y la bold van en el tema del
/// documento (`fontWeight: pw.FontWeight.bold` elige la bold); la media se
/// pide explícitamente.
class PdfReportStyle {
  final pw.Font regular;
  final pw.Font middle;
  final pw.Font bold;
  final pw.ImageProvider logo;

  const PdfReportStyle({
    required this.regular,
    required this.middle,
    required this.bold,
    required this.logo,
  });

  static PdfReportStyle? _cache;

  /// Inter va en los assets: el reporte no depende de la red y las tildes
  /// salen siempre bien (Helvetica no tiene Unicode).
  static Future<PdfReportStyle> load() async {
    if (_cache case final style?) return style;
    Future<pw.Font> source(String weight) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    final logo = await rootBundle.load('assets/images/logo_finnegans.png');
    return _cache = PdfReportStyle(
      regular: await source('Regular'),
      middle: await source('Medium'),
      bold: await source('Bold'),
      logo: pw.MemoryImage(logo.buffer.asUint8List()),
    );
  }

  pw.TextStyle mediumText(double fontSize) =>
      pw.TextStyle(font: middle, fontSize: fontSize);
}

extension PdfLevelColors on ReportLevel {
  PdfColor get color => switch (this) {
    ReportLevel.ok => PdfReportColors.ok,
    ReportLevel.attention => PdfReportColors.attention,
    ReportLevel.critical => PdfReportColors.critical,
  };

  PdfColor get background => switch (this) {
    ReportLevel.ok => PdfReportColors.okBackground,
    ReportLevel.attention => PdfReportColors.attentionBackground,
    ReportLevel.critical => PdfReportColors.criticalBackground,
  };
}

const bold = pw.FontWeight.bold;

String pdfHours(double hours) => '${hours.toStringAsFixed(1)} h';

String pdfWholeHours(double hours) => '${hours.toStringAsFixed(0)} h';

String hoursDifferencePdf(double value) {
  if (value.abs() < 0.05) return '0.0 h';
  return '${value > 0 ? '+' : '-'}${value.abs().toStringAsFixed(1)} h';
}

String pdfDateTime(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
