import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/status_colors.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:app_finnegans/features/areas/presentation/widgets/area_team_card.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/moodle_crm_comparison_cards.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_kpi_section.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';

class AreaDetailScreen extends ConsumerWidget {
  final String areaName;

  const AreaDetailScreen({super.key, required this.areaName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(areaDetailProvider(areaName));
    // Mantener la selección durante cargas o períodos sin integrantes.
    final membersFilter = ref.watch(areaMemberStatusFilterProvider);
    final hasDataAsync = ref.watch(hasTeamPeriodDataProvider);
    final scope = ref.watch(periodFilterProvider).scope;
    final month = ref.watch(periodFilterProvider).month;
    final year = ref.watch(periodFilterProvider).year;
    final periodControls = PeriodFilterPanel(
      included: 'todas las áreas',
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
          AppTopBar(title: 'Detalle de área', onBack: () => context.pop()),
          Expanded(
            child: detailAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar el área',
                error: error,
              ),
              data: (detail) => FadeIn(
                child: (() {
                  final period = periodLabel(scope, month, year);
                  final hasData = hasDataAsync.value ?? true;

                  return ListView(
                    padding: screenPadding,
                    children: [
                      periodControls,
                      const SizedBox(height: 22),
                      if (!hasData)
                        EmptyDataState.periodWithoutData(
                          icon: Icons.apartment_outlined,
                          period: period,
                        )
                      else if (detail == null)
                        EmptyDataState(
                          icon: Icons.apartment_outlined,
                          title:
                              'El área $areaName no tiene colaboradores elegibles en $period.',
                          message:
                              'Probá otro período o verificá la nómina del área.',
                        )
                      else
                        _AreaContent(
                          detail: detail,
                          filter: membersFilter,
                          period: detailedPeriodLabel(scope, month, year),
                          isAnnual: scope == PeriodScope.annual,
                          origin: origin,
                        ),
                    ],
                  );
                })(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaContent extends ConsumerWidget {
  final AreaDetailViewModel detail;
  final Set<String> filter;
  final String period;
  final bool isAnnual;
  final String origin;

  const _AreaContent({
    required this.detail,
    required this.filter,
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
              suffix: 'nómina del área',
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
              value: _hours(area.targetHours),
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
            complianceKpiCard(
              context,
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
              projectionKpiCard(context, projection),
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
        AreaMembersTable(
          members: detail.members,
          filter: filter,
          onFilter: (value) =>
              ref.read(areaMemberStatusFilterProvider.notifier).state = value,
        ),
      ],
    );
  }

  String _hours(double value) => '${value.toStringAsFixed(1)} h';
}
