import 'package:app_finnegans/core/theme/colores_reporte_pdf.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/reportes/pdf/componentes_pdf.dart';
import 'package:app_finnegans/presentation/reportes/pdf/estilo_reporte_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Encabezado de la primera página: marca, tipo, título, estado y período.
class PortadaPdf extends pw.StatelessWidget {
  final ReporteFormacion reporte;
  final EstiloReportePdf estilo;
  final DateTime generado;

  PortadaPdf(this.reporte, this.estilo, {required this.generado});

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
            child: pw.Image(estilo.logo, width: 26, height: 26),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            'FINNEGANS · FORMACIÓN INTERNA',
            style: pw.TextStyle(
              fontWeight: negrita,
              fontSize: 8,
              letterSpacing: 1.2,
              color: ColoresReportePdf.tintaSuave,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Generado el ${fechaHoraPdf(generado)}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: ColoresReportePdf.tintaSuave,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 18),
      pw.Text(
        reporte.tipo.label.toUpperCase(),
        style: pw.TextStyle(
          fontWeight: negrita,
          fontSize: 9,
          letterSpacing: 1,
          color: ColoresReportePdf.marca,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Text(
              reporte.titulo,
              style: pw.TextStyle(
                fontWeight: negrita,
                fontSize: 22,
                color: ColoresReportePdf.tinta,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          ChipEstadoPdf(reporte.estado, reporte.nivel, grande: true),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 14,
        runSpacing: 2,
        children: [
          _dato('Período', reporte.periodo),
          for (final detalle in reporte.detalles)
            pw.Text(
              detalle,
              style: const pw.TextStyle(
                color: ColoresReportePdf.tintaSuave,
                fontSize: 9,
              ),
            ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Container(height: 2, color: ColoresReportePdf.marca),
    ],
  );

  pw.Widget _dato(String etiqueta, String valor) => pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$etiqueta: ',
          style: const pw.TextStyle(
            color: ColoresReportePdf.tintaSuave,
            fontSize: 9,
          ),
        ),
        pw.TextSpan(text: valor, style: estilo.textoMedio(9)),
      ],
    ),
  );
}

/// Encabezado de las páginas siguientes a la primera.
class EncabezadoCortoPdf extends pw.StatelessWidget {
  final ReporteFormacion reporte;
  final EstiloReportePdf estilo;

  EncabezadoCortoPdf(this.reporte, this.estilo);

  @override
  pw.Widget build(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: ColoresReportePdf.linea)),
    ),
    child: pw.Row(
      children: [
        pw.Text(
          '${reporte.tipo.label} · ${reporte.titulo}',
          style: estilo.textoMedio(8),
        ),
        pw.Spacer(),
        pw.Text(
          reporte.periodo,
          style: const pw.TextStyle(
            fontSize: 8,
            color: ColoresReportePdf.tintaSuave,
          ),
        ),
      ],
    ),
  );
}

class PiePdf extends pw.StatelessWidget {
  final int pagina;
  final int paginas;

  PiePdf({required this.pagina, required this.paginas});

  @override
  pw.Widget build(pw.Context context) {
    const estilo = pw.TextStyle(
      fontSize: 7,
      color: ColoresReportePdf.tintaSuave,
    );
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        children: [
          pw.Text('Plan de formación interna · uso interno', style: estilo),
          pw.Spacer(),
          pw.Text('Página $pagina de $paginas', style: estilo),
        ],
      ),
    );
  }
}
