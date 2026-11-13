import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_colors.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/core/navigation/app_destination.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_detail_summary.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_members_table.dart';
import 'package:app_finnegans/features/reports/presentation/widgets/print_report_button.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_teams_grid.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/moodle_crm_comparison_cards.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_kpi_section.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:app_finnegans/features/projection/presentation/widgets/compliance_kpi_cards.dart';

class AreaDetailScreen extends ConsumerWidget {
  final String areaName;

  const AreaDetailScreen({super.key, required this.areaName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the members filter while the detail reloads.
    ref.watch(areaMemberStatusFilterProvider);
    final period = ref.watch(periodFilterProvider);
    final periodControls = PeriodFilterPanel(
      included: 'los integrantes del área elegibles',
      action: PrintReportButton(report: areaReportProvider(areaName)),
    );
    final requestedOrigin = GoRouterState.of(
      context,
    ).uri.queryParameters['origen'];
    const validOrigins = {'dashboard', 'areas', 'equipos'};
    final origin = validOrigins.contains(requestedOrigin)
        ? requestedOrigin!
        : 'areas';

    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          AppTopBar(
            title: 'Detalle de área',
            backTo: originBackPath(origin, '/areas'),
          ),
          Expanded(
            child: ref
                .watch(hasTeamPeriodDataProvider)
                .when(
                  skipLoadingOnReload: true,
                  loading: () => const _Loading(),
                  error: (error, _) => ErrorDataState(
                    title: 'No pudimos cargar el área',
                    error: error,
                    onRetry: () => ref.invalidate(hasTeamPeriodDataProvider),
                  ),
                  data: (hasData) => hasData
                      ? _AreaDetailBody(
                          areaName: areaName,
                          origin: origin,
                          periodControls: periodControls,
                        )
                      : FadeIn(
                          child: _PeriodList(
                            periodControls: periodControls,
                            child: EmptyDataState.periodWithoutData(
                              icon: Icons.apartment_outlined,
                              period: periodLabel(
                                period.scope,
                                period.month,
                                period.year,
                              ),
                            ),
                          ),
                        ),
                ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(color: context.colorScheme.primary),
  );
}

class _PeriodList extends StatelessWidget {
  final Widget periodControls;
  final Widget child;

  const _PeriodList({required this.periodControls, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: screenPadding,
      children: [periodControls, const SizedBox(height: 22), child],
    );
  }
}

class _AreaDetailBody extends ConsumerWidget {
  final String areaName;
  final String origin;
  final Widget periodControls;

  const _AreaDetailBody({
    required this.areaName,
    required this.origin,
    required this.periodControls,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);

    return ref
        .watch(areaDetailProvider(areaName))
        .when(
          skipLoadingOnReload: true,
          loading: () => const _Loading(),
          error: (error, _) => ErrorDataState(
            title: 'No pudimos cargar el área',
            error: error,
            onRetry: () => ref.invalidate(areaDetailProvider(areaName)),
          ),
          data: (detail) => FadeIn(
            child: _PeriodList(
              periodControls: periodControls,
              child: detail == null
                  ? EmptyDataState(
                      icon: Icons.apartment_outlined,
                      title:
                          'El área $areaName no tiene colaboradores elegibles en ${periodLabel(period.scope, period.month, period.year)}.',
                      message:
                          'Probá otro período o verificá los colaboradores del área.',
                    )
                  : _AreaContent(
                      areaName: areaName,
                      detail: detail,
                      period: detailedPeriodLabel(
                        period.scope,
                        period.month,
                        period.year,
                      ),
                      isAnnual: period.scope == PeriodScope.annual,
                      origin: origin,
                    ),
            ),
          ),
        );
  }
}

class _AreaContent extends ConsumerWidget {
  final String areaName;
  final AreaDetail detail;
  final String period;
  final bool isAnnual;
  final String origin;

  const _AreaContent({
    required this.areaName,
    required this.detail,
    required this.period,
    required this.isAnnual,
    required this.origin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = detail.area;
    final year = ref.watch(periodFilterProvider).year;
    final month = ref.watch(periodFilterProvider).month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AreaDetailHeader(area: area, period: period),
        const SizedBox(height: 22),
        KpiCardRow(
          cards: [
            DashboardKpiCard(
              title: 'INTEGRANTES',
              value: '${area.memberCount}',
              suffix: area.memberCount == 1
                  ? 'colaborador del área'
                  : 'colaboradores del área',
              progress: area.memberCount == 0
                  ? 0
                  : area.membersOnTarget / area.memberCount,
              progressLabel:
                  '${area.membersOnTarget} de ${area.memberCount} en objetivo',
              footer: '',
              icon: Icons.people_outline,
              color: context.colorScheme.primary,
              help: membersHelp('del área'),
            ),
            creditedHoursKpiCard(
              context,
              isAnnual: isAnnual,
              year: year,
              month: month,
              hours: area.completedHours,
              target: area.targetHours,
            ),
            DashboardKpiCard(
              title: 'OBJETIVO DEL PERÍODO',
              value: '${formatHours(area.targetHours)} hs',
              suffix: 'según seniority',
              progress: 1,
              progressLabel: isAnnual
                  ? 'Suma de los objetivos del año'
                  : 'Objetivo del mes',
              footer: '',
              icon: Icons.flag_outlined,
              color: context.colors.violetAccent,
              help: targetHelp('el área'),
            ),
            ComplianceKpiCard(
              isAnnual: isAnnual,
              year: year,
              month: month,
              percentage: area.compliancePercentage,
              variation: ref
                  .watch(
                    complianceVariationProvider((area: area.name, team: null)),
                  )
                  .value,
              color: area.level.colors(context).text,
            ),
            if (ref
                    .watch(
                      annualProjectionProvider((area: area.name, team: null)),
                    )
                    .value
                case final projection?)
              ProjectionKpiCard(projection: projection),
          ],
        ),
        const SizedBox(height: 16),
        AreaDetailSummary(area: area, isAnnual: isAnnual),
        if (detail.members.isNotEmpty) ...[
          const SizedBox(height: 16),
          MoodleCrmComparisonCards(complianceList: detail.members),
        ],
        const SizedBox(height: 24),
        AreaTeamsGrid(teams: detail.teams, isAnnual: isAnnual, origin: origin),
        const SizedBox(height: 24),
        AreaMembersTable(areaName: areaName),
      ],
    );
  }
}
