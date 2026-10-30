import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_kpis_service.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/area_compliance_providers.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/report_pdf.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Arman el reporte de cada pantalla con los mismos cálculos que sus cards.
// `null` cuando el período no tiene nada para reportar.

final dashboardReportProvider = FutureProvider<TrainingReport?>((ref) async {
  final period = _period(ref);
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) return null;
  final complianceList = await ref.watch(dashboardComplianceProvider.future);
  if (complianceList.isEmpty) return null;

  final timeEntries = await ref.watch(dashboardTimeEntriesProvider.future);
  final evaluatedMonths = await ref.watch(
    dashboardEvaluatedMonthsProvider.future,
  );
  final areas = await ref.watch(complianceByAreaProvider.future);
  final teams = await ref.watch(teamOverviewsProvider.future);
  final evolution = await ref.watch(dashboardMonthlyEvolutionProvider.future);
  final projection = await _optionalProjection(ref, (area: null, team: null));

  final kpis = const DashboardKpisService().calculate(
    complianceList: complianceList,
    timeEntries: timeEntries,
    evaluatedMonths: evaluatedMonths,
  );
  final status = ComplianceLevel.fromPercentage(kpis.compliance);
  return TrainingReport(
    type: ReportType.general,
    title: 'Plan de formación interna',
    details: [
      '${areas.length} áreas · ${teams.length} equipos',
      '${kpis.training} de ${kpis.employees} capacitándose',
    ],
    period: period,
    memberCount: kpis.employees,
    onTarget: _onTarget(complianceList),
    hours: kpis.creditedHours,
    target: kpis.targetHours,
    percentage: kpis.compliance,
    status: status.label,
    level: _reportLevelOf(status),
    projection: projection,
    members: complianceList,
    breakdown: [
      for (final area in areas)
        ReportBreakdownRow(
          name: area.area,
          memberCount: area.employeeCount,
          hours: area.completedHours,
          target: area.requiredHours,
          percentage: area.compliancePercentage,
          status: area.level.label,
          level: _reportLevelOf(area.level),
        ),
    ],
    evolution: evolution,
  );
});

final areaReportProvider = FutureProvider.family<TrainingReport?, String>((
  ref,
  areaName,
) async {
  final period = _period(ref);
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) return null;
  final detail = await ref.watch(areaDetailProvider(areaName).future);
  if (detail == null) return null;

  final area = detail.area;
  final projection = await _optionalProjection(ref, (
    area: area.name,
    team: null,
  ));
  return TrainingReport(
    type: ReportType.area,
    title: area.name,
    details: [
      if (area.leaders case final leaders? when leaders.trim().isNotEmpty)
        'Líder: $leaders',
      '${detail.teams.length} equipos',
    ],
    period: period,
    memberCount: area.memberCount,
    onTarget: area.membersOnTarget,
    hours: area.completedHours,
    target: area.targetHours,
    percentage: area.compliancePercentage,
    status: area.level.label,
    level: _reportLevelOf(area.level),
    projection: projection,
    members: detail.members,
    breakdown: [
      for (final team in detail.teams)
        ReportBreakdownRow(
          name: team.name,
          memberCount: team.memberCount,
          hours: team.completedHours,
          target: team.targetHours,
          percentage: team.completionPercentage,
          status: team.status.label,
          level: _teamLevel(team.status),
        ),
    ],
  );
});

final teamReportProvider =
    FutureProvider.family<TrainingReport?, ({String area, String team})>((
      ref,
      section,
    ) async {
      final period = _period(ref);
      if (!await ref.watch(hasTeamPeriodDataProvider.future)) return null;
      final detail = await ref.watch(teamDetailProvider(section).future);
      if (detail == null) return null;

      final team = detail.overview;
      final projection = await _optionalProjection(ref, (
        area: team.area,
        team: team.name,
      ));
      return TrainingReport(
        type: ReportType.team,
        title: team.name,
        details: [
          'Área: ${team.area}',
          if (team.leader.trim().isNotEmpty) 'Líder: ${team.leader}',
        ],
        period: period,
        memberCount: team.memberCount,
        onTarget: team.membersOnTarget,
        hours: team.completedHours,
        target: team.targetHours,
        percentage: team.completionPercentage,
        status: team.status.label,
        level: _teamLevel(team.status),
        projection: projection,
        members: detail.members,
      );
    });

typedef PrintReport = Future<void> Function(TrainingReport report);

/// Maqueta el PDF y abre el diálogo de impresión. Los tests lo reemplazan
/// para no depender de las fuentes ni del diálogo del sistema.
final printReportProvider = Provider<PrintReport>((ref) {
  final print = ref.watch(printRepositoryProvider);
  return (report) async {
    // Se genera antes de abrir el diálogo, así un error llega a quien llamó.
    final bytes = await generateReportPdf(report);
    await print.printPdf(bytes, fileName: report.fileName);
  };
});

String _period(Ref ref) => detailedPeriodLabel(
  ref.watch(periodFilterProvider).scope,
  ref.watch(periodFilterProvider).month,
  ref.watch(periodFilterProvider).year,
);

/// La proyección es una tarjeta opcional: si falla, el reporte sale sin ella,
/// igual que la pantalla, que oculta la card.
Future<AnnualProjection?> _optionalProjection(
  Ref ref,
  ({String? area, String? team}) section,
) async {
  try {
    return await ref.watch(annualProjectionProvider(section).future);
  } catch (_) {
    return null;
  }
}

/// En el anual, quien cambió de equipo figura una vez por etapa: se cuenta
/// una sola vez.
int _onTarget(List<EmployeeCompliance> members) => {
  for (final m in members)
    if (m.meetsTarget) m.employee.employeeId,
}.length;

ReportLevel _reportLevelOf(ComplianceLevel status) => switch (status) {
  ComplianceLevel.onTarget => ReportLevel.ok,
  ComplianceLevel.atRisk => ReportLevel.attention,
  ComplianceLevel.critical => ReportLevel.critical,
};

ReportLevel _teamLevel(TeamStatus status) => switch (status) {
  TeamStatus.onTarget => ReportLevel.ok,
  TeamStatus.atRisk => ReportLevel.attention,
  TeamStatus.critical => ReportLevel.critical,
};
