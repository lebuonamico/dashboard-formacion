import 'package:app_finnegans/features/compliance/domain/moodle_crm_comparison.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/moodle_crm_comparison_service.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';

/// Qué sección de la app resume el reporte.
enum ReportType {
  general('Reporte general', breakdownTitle: 'Cumplimiento por área'),
  area('Reporte de área', breakdownTitle: 'Cumplimiento por equipo'),
  team('Reporte de equipo');

  final String label;

  /// Título de la tabla de desglose; `null` si el reporte no tiene desglose.
  final String? breakdownTitle;

  const ReportType(this.label, {this.breakdownTitle});
}

/// Semáforo de una fila del reporte, ya resuelto por quien lo arma.
enum ReportLevel { ok, attention, critical }

/// Mismos cortes que el semáforo de la app.
ReportLevel reportLevelFor(double percentage) =>
    switch (const ComplianceLevelService().fromPercentage(percentage)) {
      ComplianceLevel.onTarget => ReportLevel.ok,
      ComplianceLevel.atRisk => ReportLevel.attention,
      ComplianceLevel.critical => ReportLevel.critical,
    };

/// Qué dato de ubicación acompaña a cada integrante en la tabla.
enum MemberLocation { none, team, teamAreaY }

typedef ReportCategoryHours = ({
  CourseCategory tipo,
  double validas,
  double objetivo,
});

/// Una fila del desglose: áreas en el general, equipos en el de área.
class ReportBreakdownRow {
  final String name;
  final int memberCount;
  final double hours;
  final double target;
  final double percentage;
  final String status;
  final ReportLevel level;

  const ReportBreakdownRow({
    required this.name,
    required this.memberCount,
    required this.hours,
    required this.target,
    required this.percentage,
    required this.status,
    required this.level,
  });
}

/// Todo lo que muestra el reporte, con los mismos números que la pantalla.
class TrainingReport {
  final ReportType type;
  final String title;

  /// Líneas cortas bajo el título: área, líder, etc.
  final List<String> details;
  final String period;

  final int memberCount;
  final int onTarget;
  final double hours;
  final double target;
  final double percentage;
  final String status;
  final ReportLevel level;

  final AnnualProjection? projection;
  final List<EmployeeCompliance> members;
  final List<ReportBreakdownRow> breakdown;

  /// Horas válidas por persona de los últimos meses (solo el general).
  final List<({DateTime month, double hours})> evolution;

  const TrainingReport({
    required this.type,
    required this.title,
    this.details = const [],
    required this.period,
    required this.memberCount,
    required this.onTarget,
    required this.hours,
    required this.target,
    required this.percentage,
    required this.status,
    required this.level,
    this.projection,
    required this.members,
    this.breakdown = const [],
    this.evolution = const [],
  });

  /// En el general la nómina es larga: se listan solo los críticos.
  bool get criticalOnly => type == ReportType.general;

  MemberLocation get memberLocation => switch (type) {
    ReportType.general => MemberLocation.teamAreaY,
    ReportType.area => MemberLocation.team,
    ReportType.team => MemberLocation.none,
  };

  String get fileName {
    final base = '${type.label} $title $period'
        .toLowerCase()
        .replaceAll(RegExp(r'[áà]'), 'a')
        .replaceAll(RegExp(r'[éè]'), 'e')
        .replaceAll(RegExp(r'[íì]'), 'i')
        .replaceAll(RegExp(r'[óò]'), 'o')
        .replaceAll(RegExp(r'[úù]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '$base.pdf';
  }

  /// Cuántas personas evaluadas caen en cada nivel del semáforo.
  Map<ReportLevel, int> get countByLevel {
    final count = {for (final level in ReportLevel.values) level: 0};
    for (final member in members) {
      final level = reportLevelFor(member.totalPercentage);
      count[level] = count[level]! + 1;
    }
    return count;
  }

  /// Cada persona suma hasta su objetivo en cada categoría, y nada en las que
  /// su seniority no pide: son las horas que cuentan para la meta.
  List<ReportCategoryHours> get hoursByCategory {
    double sum(double Function(EmployeeCompliance) value) =>
        members.fold(0, (t, m) => t + value(m));
    return [
      for (final type in CourseCategory.values)
        (
          tipo: type,
          validas: sum((m) => m.applicableHours[type]!),
          objetivo: sum((m) => m.requiredHours[type] ?? 0),
        ),
    ];
  }

  MoodleCrmComparison get sourceComparison =>
      const MoodleCrmComparisonService().compare(members);

  /// De menor a mayor cumplimiento, y por nombre a igual porcentaje.
  List<EmployeeCompliance> get listedMembers {
    final sorted = [...members]
      ..sort((a, b) {
        final percentage = a.totalPercentage.compareTo(b.totalPercentage);
        return percentage != 0
            ? percentage
            : const EmployeeLookupService()
                  .fullName(a.employee)
                  .compareTo(
                    const EmployeeLookupService().fullName(b.employee),
                  );
      });
    if (!criticalOnly) return sorted;
    return [
      for (final m in sorted)
        if (reportLevelFor(m.totalPercentage) == ReportLevel.critical) m,
    ];
  }

  /// De menor a mayor cumplimiento: lo que peor está, primero.
  List<ReportBreakdownRow> get sortedBreakdown =>
      [...breakdown]..sort((a, b) => a.percentage.compareTo(b.percentage));
}
