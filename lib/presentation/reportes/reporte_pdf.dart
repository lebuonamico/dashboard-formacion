import 'dart:typed_data';

import 'package:app_finnegans/core/theme/colores_reporte_pdf.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/reportes/pdf/encabezados_pdf.dart';
import 'package:app_finnegans/presentation/reportes/pdf/estilo_reporte_pdf.dart';
import 'package:app_finnegans/presentation/reportes/pdf/secciones_resumen_pdf.dart';
import 'package:app_finnegans/presentation/reportes/pdf/secciones_tablas_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Maqueta el reporte en A4. La impresión la hace `ImpresionRepository`.
Future<Uint8List> generarReportePdf(ReporteFormacion reporte) async {
  final estilo = await EstiloReportePdf.cargar();
  final doc = pw.Document(
    title: '${reporte.tipo.label} · ${reporte.titulo}',
    author: 'Finnegans · Formación interna',
  );
  final generado = DateTime.now();
  // Una instancia por posición: los widgets del PDF guardan su maquetado.
  pw.Widget separacion() => pw.SizedBox(height: 18);

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
        theme: pw.ThemeData.withFont(base: estilo.regular, bold: estilo.bold)
            .copyWith(
              defaultTextStyle: const pw.TextStyle(
                fontSize: 9,
                color: ColoresReportePdf.tinta,
              ),
            ),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : EncabezadoCortoPdf(reporte, estilo),
      footer: (context) =>
          PiePdf(pagina: context.pageNumber, paginas: context.pagesCount),
      // Los bloques cortos no se parten entre páginas; las tablas largas sí,
      // repitiendo su encabezado.
      build: (context) => [
        PortadaPdf(reporte, estilo, generado: generado),
        pw.SizedBox(height: 16),
        pw.Inseparable(child: KpisPdf(reporte)),
        separacion(),
        pw.Inseparable(child: EstadoPersonasPdf(reporte)),
        separacion(),
        pw.Inseparable(child: CategoriasPdf(reporte)),
        separacion(),
        pw.Inseparable(child: FuentesPdf(reporte)),
        if (reporte.evolucion.isNotEmpty) ...[
          separacion(),
          pw.Inseparable(child: EvolucionPdf(reporte)),
        ],
        if (reporte.desglose.isNotEmpty) ...[
          separacion(),
          ...desglosePdf(reporte, estilo),
        ],
        separacion(),
        ...integrantesPdf(reporte, estilo),
        pw.SizedBox(height: 14),
        pw.Inseparable(child: NotasPdf()),
      ],
    ),
  );
  return doc.save();
}
