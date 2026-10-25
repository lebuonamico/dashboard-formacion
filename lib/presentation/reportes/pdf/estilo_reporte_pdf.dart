import 'package:app_finnegans/core/theme/colores_reporte_pdf.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fuentes y logo del reporte. La regular y la bold van en el tema del
/// documento (`fontWeight: pw.FontWeight.bold` elige la bold); la media se
/// pide explícitamente.
class EstiloReportePdf {
  final pw.Font regular;
  final pw.Font medio;
  final pw.Font bold;
  final pw.ImageProvider logo;

  const EstiloReportePdf({
    required this.regular,
    required this.medio,
    required this.bold,
    required this.logo,
  });

  static EstiloReportePdf? _cache;

  /// Inter va en los assets: el reporte no depende de la red y las tildes
  /// salen siempre bien (Helvetica no tiene Unicode).
  static Future<EstiloReportePdf> cargar() async {
    if (_cache case final estilo?) return estilo;
    Future<pw.Font> fuente(String peso) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-$peso.ttf'));
    final logo = await rootBundle.load('assets/images/logo_finnegans.png');
    return _cache = EstiloReportePdf(
      regular: await fuente('Regular'),
      medio: await fuente('Medium'),
      bold: await fuente('Bold'),
      logo: pw.MemoryImage(logo.buffer.asUint8List()),
    );
  }

  pw.TextStyle textoMedio(double fontSize) =>
      pw.TextStyle(font: medio, fontSize: fontSize);
}

extension ColoresNivelPdf on NivelReporte {
  PdfColor get color => switch (this) {
    NivelReporte.ok => ColoresReportePdf.ok,
    NivelReporte.atencion => ColoresReportePdf.atencion,
    NivelReporte.critico => ColoresReportePdf.critico,
  };

  PdfColor get fondo => switch (this) {
    NivelReporte.ok => ColoresReportePdf.okFondo,
    NivelReporte.atencion => ColoresReportePdf.atencionFondo,
    NivelReporte.critico => ColoresReportePdf.criticoFondo,
  };
}

const negrita = pw.FontWeight.bold;

String horasPdf(double horas) => '${horas.toStringAsFixed(1)} h';

String horasEnterasPdf(double horas) => '${horas.toStringAsFixed(0)} h';

String diferenciaHorasPdf(double valor) {
  if (valor.abs() < 0.05) return '0.0 h';
  return '${valor > 0 ? '+' : '-'}${valor.abs().toStringAsFixed(1)} h';
}

String fechaHoraPdf(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}
