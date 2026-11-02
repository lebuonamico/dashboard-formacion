import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/reports/presentation/providers/print_repository_provider.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/report_pdf.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/features/reports/domain/training_report_builder.dart';
import 'package:app_finnegans/features/reports/presentation/report_labels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trainingReportBuilderProvider = Provider<TrainingReportBuilder>(
  (ref) => const TrainingReportBuilder(),
);

/// `null` when the period has nothing to report.
final dashboardReportProvider = FutureProvider<TrainingReport?>((ref) async {
  final period = _period(ref);
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) return null;
  final summary = await ref.watch(dashboardKpisProvider.future);
  if (summary == null) return null;

  final members = await ref.watch(dashboardComplianceProvider.future);
  final areas = await ref.watch(areasByComplianceProvider.future);
  final evolution = await ref.watch(dashboardMonthlyEvolutionProvider.future);
  final projection = await _optionalProjection(ref, (area: null, team: null));
  return ref
      .watch(trainingReportBuilderProvider)
      .general(
        title: 'Plan de formación interna',
        period: period,
        kpis: summary.kpis,
        areaCount: summary.areaCount,
        teamCount: summary.teamCount,
        areas: areas,
        members: members,
        projection: projection,
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

  final projection = await _optionalProjection(ref, (
    area: detail.area.name,
    team: null,
  ));
  return ref
      .watch(trainingReportBuilderProvider)
      .area(period: period, detail: detail, projection: projection);
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

      final projection = await _optionalProjection(ref, (
        area: detail.overview.area,
        team: detail.overview.name,
      ));
      return ref
          .watch(trainingReportBuilderProvider)
          .team(period: period, detail: detail, projection: projection);
    });

typedef PrintReport = Future<void> Function(TrainingReport report);

/// Lays out the PDF and opens the print dialog. Tests replace it so they
/// do not depend on the fonts or the system dialog.
final printReportProvider = Provider<PrintReport>((ref) {
  final print = ref.watch(printRepositoryProvider);
  return (report) async {
    // Generated before opening the dialog, so an error reaches the caller.
    final bytes = await generateReportPdf(report);
    await print.printPdf(bytes, fileName: reportFileName(report));
  };
});

String _period(Ref ref) => detailedPeriodLabel(
  ref.watch(periodFilterProvider).scope,
  ref.watch(periodFilterProvider).month,
  ref.watch(periodFilterProvider).year,
);

/// The projection is an optional card: if it fails, the report goes out
/// without it, as the screen hides the card.
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
