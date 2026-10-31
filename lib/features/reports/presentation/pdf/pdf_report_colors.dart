import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:pdf/pdf.dart';

/// Paleta del reporte impreso: tinta azul noche y celeste de la marca, con un
/// semáforo sobrio. El papel es siempre blanco, así que no sigue el tema
/// claro/oscuro de la app.
abstract final class PdfReportColors {
  static const ink = PdfColor.fromInt(0xFF0B1B3A);
  static const softInk = PdfColor.fromInt(0xFF5B6478);
  static const white = PdfColor.fromInt(0xFFFFFFFF);
  static const line = PdfColor.fromInt(0xFFE3E7EE);
  static const softBackground = PdfColor.fromInt(0xFFF5F7FA);
  static const brand = PdfColor.fromInt(0xFF3FB6F5);
  static const brandBackground = PdfColor.fromInt(0xFFE7F5FD);
  static const track = PdfColor.fromInt(0xFFE9EDF3);

  static const ok = PdfColor.fromInt(0xFF15803D);
  static const attention = PdfColor.fromInt(0xFFB45309);
  static const critical = PdfColor.fromInt(0xFFB91C1C);
  static const okBackground = PdfColor.fromInt(0xFFE6F4EA);
  static const attentionBackground = PdfColor.fromInt(0xFFFDF1DC);
  static const criticalBackground = PdfColor.fromInt(0xFFFCE4E4);

  static const category = {
    CourseCategory.businessSkills: PdfColor.fromInt(0xFF3B82F6),
    CourseCategory.softSkills: PdfColor.fromInt(0xFF8B5CF6),
    CourseCategory.exploration: PdfColor.fromInt(0xFF10B981),
    CourseCategory.teaching: PdfColor.fromInt(0xFFF59E0B),
  };
}
