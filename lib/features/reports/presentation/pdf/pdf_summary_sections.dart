import 'package:app_finnegans/core/theme/pdf_report_colors.dart';
import 'package:app_finnegans/features/compliance/domain/moodle_crm_comparison.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/projection/domain/projection_service.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_components.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_report_style.dart';
import 'package:app_finnegans/core/period/period_formatter.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Las mismas tarjetas que la pantalla: integrantes, horas, cumplimiento y,
/// si hay, la proyección a diciembre.
class KpisPdf extends pw.StatelessWidget {
  final TrainingReport report;

  KpisPdf(this.report);

  @override
  pw.Widget build(pw.Context context) {
    final r = report;
    final missing = (r.target - r.hours).clamp(0.0, double.infinity);
    final cards = [
      _CardKpiPdf(
        title: 'INTEGRANTES',
        value: '${r.memberCount}',
        detail: '${r.onTarget} en objetivo',
        progress: r.memberCount == 0 ? 0 : r.onTarget / r.memberCount,
        color: PdfReportColors.brand,
      ),
      _CardKpiPdf(
        title: 'HORAS VÁLIDAS',
        value: pdfHours(r.hours),
        detail: 'de ${pdfWholeHours(r.target)} · faltan ${pdfHours(missing)}',
        progress: r.target == 0 ? 0 : r.hours / r.target,
        color: PdfReportColors.brand,
      ),
      _CardKpiPdf(
        title: 'CUMPLIMIENTO',
        value: formatPercentage(r.percentage),
        detail: r.status,
        progress: r.percentage / 100,
        color: r.level.color,
        valueColor: r.level.color,
      ),
      if (r.projection case final p?)
        _CardKpiPdf(
          title: 'PROYECCIÓN A DIC.',
          value: formatPercentage(p.percentage),
          detail:
              '${p.status.label} · ${p.arrive} de ${p.employeeCount} llegan',
          progress: p.percentage / 100,
          color: switch (p.status) {
            ProjectionStatus.onTrack => ReportLevel.ok.color,
            ProjectionStatus.reachable => ReportLevel.attention.color,
            ProjectionStatus.atRisk => ReportLevel.critical.color,
          },
        ),
    ];
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(child: card),
        ],
      ],
    );
  }
}

class _CardKpiPdf extends pw.StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final double progress;
  final PdfColor color;
  final PdfColor? valueColor;

  _CardKpiPdf({
    required this.title,
    required this.value,
    required this.detail,
    required this.progress,
    required this.color,
    this.valueColor,
  });

  @override
  pw.Widget build(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 10),
    decoration: pw.BoxDecoration(
      color: PdfReportColors.softBackground,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: PdfReportColors.line),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: bold,
            fontSize: 6.5,
            letterSpacing: 0.6,
            color: PdfReportColors.softInk,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: bold,
            fontSize: 17,
            color: valueColor ?? PdfReportColors.ink,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          detail,
          maxLines: 1,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfReportColors.softInk,
          ),
        ),
        pw.SizedBox(height: 6),
        PdfProgressBar(progress, color, height: 4),
      ],
    ),
  );
}

/// Cómo se reparten las personas evaluadas en el semáforo.
class PdfPeopleStatus extends pw.StatelessWidget {
  final TrainingReport report;

  PdfPeopleStatus(this.report);

  static const _labels = {
    ReportLevel.ok: 'Cumple (100%)',
    ReportLevel.attention: 'Atención (70 a 99%)',
    ReportLevel.critical: 'No cumple (menos de 70%)',
  };

  @override
  pw.Widget build(pw.Context context) {
    final count = report.countByLevel;
    final total = report.members.length;
    int percentage(ReportLevel level) =>
        total == 0 ? 0 : (count[level]! / total * 100).round();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfSectionTitle(
          'Estado de cumplimiento',
          lowered:
              'Cómo se reparten las $total personas evaluadas en el semáforo',
        ),
        // Barra apilada: una lectura rápida de la proporción.
        pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Row(
            children: [
              for (final level in ReportLevel.values)
                if (count[level]! > 0)
                  pw.Expanded(
                    flex: count[level]!,
                    child: pw.Container(
                      height: 14,
                      color: level.color,
                      alignment: pw.Alignment.center,
                      child: count[level]! / total >= 0.08
                          ? pw.Text(
                              '${percentage(level)}%',
                              style: pw.TextStyle(
                                fontWeight: bold,
                                fontSize: 7,
                                color: PdfReportColors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            for (final level in ReportLevel.values) ...[
              PdfColorDot(level.color),
              pw.SizedBox(width: 4),
              pw.Text(_labels[level]!, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(width: 4),
              pw.Text(
                '${count[level]} (${percentage(level)}%)',
                style: pw.TextStyle(fontWeight: bold, fontSize: 8),
              ),
              pw.SizedBox(width: 16),
            ],
          ],
        ),
      ],
    );
  }
}

/// Horas válidas contra objetivo en cada categoría, con una fila de total.
class PdfCategories extends pw.StatelessWidget {
  final TrainingReport report;

  PdfCategories(this.report);

  @override
  pw.Widget build(pw.Context context) {
    final categories = report.hoursByCategory;
    final totalCredited = categories.fold<double>(0, (t, c) => t + c.validas);
    final totalTarget = categories.fold<double>(0, (t, c) => t + c.objetivo);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfSectionTitle(
          'Horas por categoría',
          lowered:
              'Horas válidas para la meta: cada persona suma hasta su objetivo en cada categoría.',
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfReportColors.ink, width: 0.8),
            ),
          ),
          child: pw.Row(
            children: [
              _header('CATEGORÍA', width: 150),
              _header('VÁLIDAS', width: 70, right: true),
              _header('OBJETIVO', width: 70, right: true),
              pw.SizedBox(width: 16),
              _header('AVANCE'),
              _header('%', width: 40, right: true),
            ],
          ),
        ),
        for (final c in categories)
          _row(
            name: pw.Row(
              children: [
                PdfColorDot(PdfReportColors.category[c.tipo]!),
                pw.SizedBox(width: 6),
                pw.Text(c.tipo.label, style: const pw.TextStyle(fontSize: 8.5)),
              ],
            ),
            valid: c.validas,
            target: c.objetivo,
            color: PdfReportColors.category[c.tipo]!,
          ),
        _row(
          name: pw.Text(
            'Total',
            style: pw.TextStyle(fontWeight: bold, fontSize: 8.5),
          ),
          valid: totalCredited,
          target: totalTarget,
          color: PdfReportColors.ink,
          total: true,
        ),
      ],
    );
  }

  pw.Widget _header(String text, {double? width, bool right = false}) {
    final t = pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontWeight: bold,
        fontSize: 7,
        color: PdfReportColors.softInk,
      ),
    );
    return width == null
        ? pw.Expanded(child: t)
        : pw.SizedBox(width: width, child: t);
  }

  pw.Widget _row({
    required pw.Widget name,
    required double valid,
    required double target,
    required PdfColor color,
    bool total = false,
  }) {
    final progress = target == 0 ? 1.0 : valid / target;
    final style = pw.TextStyle(fontWeight: total ? bold : null, fontSize: 8.5);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: total ? PdfReportColors.softBackground : null,
        border: const pw.Border(
          bottom: pw.BorderSide(color: PdfReportColors.line),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 150, child: name),
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              pdfHours(valid),
              style: style,
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              pdfHours(target),
              style: style.copyWith(color: PdfReportColors.softInk),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(child: PdfProgressBar(progress, color)),
          pw.SizedBox(
            width: 40,
            child: pw.Text(
              target == 0 ? '-' : formatPercentage(progress * 100),
              style: style.copyWith(fontWeight: bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horas de cada fuente sin tope, y cuánto difieren donde las dos existen.
class PdfSources extends pw.StatelessWidget {
  final TrainingReport report;

  PdfSources(this.report);

  @override
  pw.Widget build(pw.Context context) {
    final c = report.sourceComparison;
    const comparables = MoodleCrmComparison.comparables;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfSectionTitle(
          'Moodle vs CRM',
          lowered:
              'Horas registradas en cada fuente, sin tope. Libres y Dictado solo existen en CRM.',
        ),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(2.2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: PdfReportColors.line),
            bottom: pw.BorderSide(color: PdfReportColors.line),
          ),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfReportColors.ink, width: 0.8),
                ),
              ),
              children: [
                _header('CATEGORÍA', right: false),
                _header('MOODLE (LMS)'),
                _header('CRM'),
                _header('DIFERENCIA'),
              ],
            ),
            for (final type in CourseCategory.values)
              pw.TableRow(
                children: [
                  _name(type.label),
                  comparables.contains(type)
                      ? _cell(pdfHours(c.moodle[type] ?? 0))
                      : _cell('-', color: PdfReportColors.softInk),
                  _cell(pdfHours(c.crm[type] ?? 0)),
                  _cell(
                    comparables.contains(type)
                        ? hoursDifferencePdf(
                            (c.crm[type] ?? 0) - (c.moodle[type] ?? 0),
                          )
                        : '-',
                    color: PdfReportColors.softInk,
                  ),
                ],
              ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfReportColors.softBackground,
              ),
              children: [
                _name('Total', highlighted: true),
                _cell(pdfHours(c.totalMoodle(comparables)), highlighted: true),
                _cell(
                  pdfHours(c.totalCrm(CourseCategory.values)),
                  highlighted: true,
                ),
                _cell(''),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: PdfReportColors.brandBackground,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            _differenceText(c),
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    );
  }

  static String _differenceText(MoodleCrmComparison c) {
    if (c.match) return 'En Negocio y Blandas las dos fuentes coinciden.';
    final difference = c.differenceComparable;
    final sign = difference > 0 ? '+' : '-';
    final percentage = switch (c.percentageDifference) {
      final p? => ' ($sign${p.abs().toStringAsFixed(0)}%)',
      null => '',
    };
    return 'En Negocio y Blandas, CRM registra ${pdfHours(difference.abs())} '
        '${difference > 0 ? 'más' : 'menos'} que Moodle$percentage.';
  }

  static const _padding = pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8);

  pw.Widget _cell(String text, {bool highlighted = false, PdfColor? color}) =>
      pw.Padding(
        padding: _padding,
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontWeight: highlighted ? bold : null,
            fontSize: 8.5,
            color: color,
          ),
        ),
      );

  pw.Widget _name(String text, {bool highlighted = false}) => pw.Padding(
    padding: _padding,
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: highlighted ? bold : null, fontSize: 8.5),
    ),
  );

  pw.Widget _header(String text, {bool right = true}) => pw.Padding(
    padding: _padding,
    child: pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontWeight: bold,
        fontSize: 7,
        color: PdfReportColors.softInk,
      ),
    ),
  );
}

/// Horas válidas promedio por colaborador de los últimos meses.
class PdfEvolution extends pw.StatelessWidget {
  final TrainingReport report;

  PdfEvolution(this.report);

  static const _height = 70.0;

  @override
  pw.Widget build(pw.Context context) {
    final evolution = report.evolution;
    final maximum = evolution.fold<double>(
      0,
      (m, point) => point.hours > m ? point.hours : m,
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfSectionTitle(
          'Evolución mensual',
          lowered:
              'Horas válidas promedio por colaborador en los últimos meses',
        ),
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: pw.BoxDecoration(
            color: PdfReportColors.softBackground,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfReportColors.line),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (final (i, point) in evolution.indexed)
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        pdfHours(point.hours),
                        style: pw.TextStyle(fontWeight: bold, fontSize: 8),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        width: 36,
                        height: maximum == 0
                            ? 1
                            : (_height * point.hours / maximum).clamp(
                                1.0,
                                _height,
                              ),
                        decoration: pw.BoxDecoration(
                          // El último mes es el del período elegido.
                          color: i == evolution.length - 1
                              ? PdfReportColors.brand
                              : PdfReportColors.track,
                          borderRadius: const pw.BorderRadius.vertical(
                            top: pw.Radius.circular(3),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${monthName(point.month.month)} ${point.month.year}',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfReportColors.softInk,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
