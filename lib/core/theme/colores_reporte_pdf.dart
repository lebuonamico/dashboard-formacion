import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:pdf/pdf.dart';

/// Paleta del reporte impreso: tinta azul noche y celeste de la marca, con un
/// semáforo sobrio. El papel es siempre blanco, así que no sigue el tema
/// claro/oscuro de la app.
abstract final class ColoresReportePdf {
  static const tinta = PdfColor.fromInt(0xFF0B1B3A);
  static const tintaSuave = PdfColor.fromInt(0xFF5B6478);
  static const blanco = PdfColor.fromInt(0xFFFFFFFF);
  static const linea = PdfColor.fromInt(0xFFE3E7EE);
  static const fondoSuave = PdfColor.fromInt(0xFFF5F7FA);
  static const marca = PdfColor.fromInt(0xFF3FB6F5);
  static const marcaFondo = PdfColor.fromInt(0xFFE7F5FD);
  static const pista = PdfColor.fromInt(0xFFE9EDF3);

  static const ok = PdfColor.fromInt(0xFF15803D);
  static const atencion = PdfColor.fromInt(0xFFB45309);
  static const critico = PdfColor.fromInt(0xFFB91C1C);
  static const okFondo = PdfColor.fromInt(0xFFE6F4EA);
  static const atencionFondo = PdfColor.fromInt(0xFFFDF1DC);
  static const criticoFondo = PdfColor.fromInt(0xFFFCE4E4);

  static const categoria = {
    TipoCurso.habilidadesDeNegocio: PdfColor.fromInt(0xFF3B82F6),
    TipoCurso.habilidadesBlandas: PdfColor.fromInt(0xFF8B5CF6),
    TipoCurso.libresExploracion: PdfColor.fromInt(0xFF10B981),
    TipoCurso.dictadoCapacitaciones: PdfColor.fromInt(0xFFF59E0B),
  };
}
