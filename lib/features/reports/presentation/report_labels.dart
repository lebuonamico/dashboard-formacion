import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';

extension ReportTypeLabel on ReportType {
  String get label => switch (this) {
    ReportType.general => 'Reporte general',
    ReportType.area => 'Reporte de área',
    ReportType.team => 'Reporte de equipo',
  };

  /// Title of the breakdown table; `null` if the report has none.
  String? get breakdownTitle => switch (this) {
    ReportType.general => 'Cumplimiento por área',
    ReportType.area => 'Cumplimiento por equipo',
    ReportType.team => null,
  };
}

extension ReportLevelLabel on ReportLevel {
  String get label => switch (this) {
    ReportLevel.ok => 'En objetivo',
    ReportLevel.attention => 'En riesgo',
    ReportLevel.critical => 'Crítico',
  };
}

/// Short lines under the title: area, leader, counts.
List<String> reportDetails(TrainingReport report) => switch (report.type) {
  ReportType.general => [
    '${report.areaCount ?? 0} áreas · ${report.teamCount ?? 0} equipos',
    '${report.trainingCount ?? 0} de ${report.memberCount} capacitándose',
  ],
  ReportType.area => [
    if (report.leaders case final leaders? when leaders.trim().isNotEmpty)
      'Líder: $leaders',
    '${report.teamCount ?? 0} equipos',
  ],
  ReportType.team => [
    'Área: ${report.area ?? ''}',
    if (report.leaders case final leader? when leader.trim().isNotEmpty)
      'Líder: $leader',
  ],
};

String reportFileName(TrainingReport report) =>
    '${normalizeKey('${report.type.label} ${report.title} ${report.period}', separator: '_')}.pdf';
