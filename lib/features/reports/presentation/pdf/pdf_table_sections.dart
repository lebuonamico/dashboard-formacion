import 'package:app_finnegans/core/theme/pdf_report_colors.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_components.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/pdf_report_style.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';

// Las tablas largas devuelven el título y la `pw.Table` por separado para
// que `MultiPage` pueda partir la tabla entre páginas (ver `tablaPdf`).

/// Áreas en el general, equipos en el de área.
List<pw.Widget> breakdownPdf(TrainingReport report, PdfReportStyle style) {
  const cellStyle = pw.TextStyle(fontSize: 8);
  return [
    PdfSectionTitle(
      report.type.breakdownTitle ?? 'Desglose',
      lowered: 'Ordenado de menor a mayor cumplimiento',
    ),
    pdfTable(
      widths: const [3, 1.1, 1.8, 1.3, 1.2],
      right: const {1, 2, 3},
      headers: const [
        'NOMBRE',
        'INTEGRANTES',
        'HORAS / OBJETIVO',
        'CUMPLIMIENTO',
        'ESTADO',
      ],
      rows: [
        for (final f in report.sortedBreakdown)
          [
            pw.Text(f.name, style: style.mediumText(8)),
            pw.Text('${f.memberCount}', style: cellStyle),
            pw.Text(
              '${pdfHours(f.hours)} / ${pdfWholeHours(f.target)}',
              style: cellStyle,
            ),
            pw.Text(
              formatPercentage(f.percentage),
              style: pw.TextStyle(
                fontWeight: bold,
                fontSize: 8,
                color: f.level.color,
              ),
            ),
            PdfStatusChip(f.status, f.level),
          ],
      ],
    ),
  ];
}

/// Integrantes con sus horas por categoría. En el general, solo los críticos.
List<pw.Widget> pdfMembers(TrainingReport report, PdfReportStyle style) {
  final items = report.listedMembers;
  final title = report.criticalOnly
      ? PdfSectionTitle(
          'Colaboradores que requieren seguimiento',
          lowered:
              '${items.length} con menos de 70% de cumplimiento, de menor a mayor. '
              'Por categoría: horas válidas / objetivo.',
        )
      : PdfSectionTitle(
          'Integrantes (${items.length})',
          lowered:
              'De menor a mayor cumplimiento. Por categoría: horas válidas / objetivo.',
        );

  if (items.isEmpty) {
    return [
      title,
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: ReportLevel.ok.background,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'Nadie está por debajo de 70% de cumplimiento en este período.',
          style: style.mediumText(8.5).copyWith(color: ReportLevel.ok.color),
        ),
      ),
    ];
  }

  final location = report.memberLocation;
  final withLocation = location != MemberLocation.none;
  const cellStyle = pw.TextStyle(fontSize: 7.5);

  return [
    title,
    pdfTable(
      widths: [
        2.3,
        if (withLocation) 1.5,
        1.4,
        for (final _ in CourseCategory.values) 1.05,
        1.3,
        0.8,
      ],
      // Categorías, horas y %: las columnas numéricas del final.
      right: {
        for (var i = 0; i < CourseCategory.values.length + 2; i++)
          i + (withLocation ? 3 : 2),
      },
      headers: [
        'COLABORADOR',
        if (withLocation)
          location == MemberLocation.teamAreaY ? 'ÁREA / EQUIPO' : 'EQUIPO',
        'SENIORITY',
        for (final type in CourseCategory.values) type.shortLabel.toUpperCase(),
        'HORAS',
        '%',
      ],
      rows: [
        for (final m in items)
          [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(m.employee.fullName, style: style.mediumText(7.5)),
                pw.Text(
                  'Legajo ${m.employee.employeeId}',
                  style: const pw.TextStyle(
                    fontSize: 6.5,
                    color: PdfReportColors.softInk,
                  ),
                ),
              ],
            ),
            if (withLocation)
              pw.Text(_location(m.employee, location), style: cellStyle),
            pw.Text(m.employee.seniority.label, style: cellStyle),
            for (final type in CourseCategory.values)
              pw.Text(_category(m, type), style: cellStyle),
            pw.Text(
              '${m.totalCreditedHours.toStringAsFixed(1)} / '
              '${m.totalRequiredHours.toStringAsFixed(0)}',
              style: cellStyle,
            ),
            pw.Text(
              formatPercentage(m.totalPercentage),
              style: pw.TextStyle(
                fontWeight: bold,
                fontSize: 7.5,
                color: reportLevelFor(m.totalPercentage).color,
              ),
            ),
          ],
      ],
    ),
  ];
}

String _location(Employee employee, MemberLocation location) =>
    switch (location) {
      MemberLocation.teamAreaY => [
        employee.area,
        employee.team,
      ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' / '),
      MemberLocation.team =>
        employee.team.trim().isEmpty ? 'Sin equipo' : employee.team.trim(),
      MemberLocation.none => '',
    };

/// Horas válidas / objetivo, o "-" si su seniority no pide esa categoría.
String _category(EmployeeCompliance m, CourseCategory type) {
  final required = m.requiredHours[type] ?? 0;
  if (required <= 0) return '-';
  return '${m.applicableHours[type]!.toStringAsFixed(1)}/'
      '${required.toStringAsFixed(0)}';
}

class PdfNotes extends pw.StatelessWidget {
  @override
  pw.Widget build(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfReportColors.line),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      'Cómo leer este reporte. Horas válidas: las que suman a la meta. '
      'Negocio y Blandas se acreditan con los cursos finalizados en Moodle; '
      'Libres y Dictado, con lo declarado en CRM. Cada persona suma como máximo '
      'su objetivo en cada categoría, según su seniority. El semáforo usa los '
      'cortes 100% (cumple) y 70% (atención).',
      style: const pw.TextStyle(
        fontSize: 7,
        color: PdfReportColors.softInk,
        lineSpacing: 2,
      ),
    ),
  );
}
