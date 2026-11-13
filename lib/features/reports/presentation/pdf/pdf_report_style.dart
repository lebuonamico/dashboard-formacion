import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_report_colors.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Report fonts and logo. Regular and bold go in the document theme
/// (`fontWeight: pw.FontWeight.bold` picks the bold); medium is requested
/// explicitly.
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

  /// Inter ships in the assets: the report does not depend on the network and
  /// accents always render (Helvetica has no Unicode).
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

String pdfHours(double hours) => '${formatHours(hours)} hs';

/// Achieved hours towards [target]; see `formatAchievedHours`.
String pdfAchievedHours(double hours, {required double target}) =>
    '${formatAchievedHours(hours, target: target)} hs';

/// With one decimal: only the monthly evolution keeps decimals.
String pdfPreciseHours(double hours) => '${formatHoursPrecise(hours)} hs';

String pdfDateTime(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
