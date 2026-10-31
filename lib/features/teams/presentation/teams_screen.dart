import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/moodle_crm_comparison_cards.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_category_distribution.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_kpi_section.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_results.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_status_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(teamsPeriodSummaryProvider);
    final filteredTeamsAsync = ref.watch(filteredTeamOverviewsProvider);

    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          const AppTopBar(title: 'Dashboard global de equipos'),
          Expanded(
            child: summaryAsync.when(
              skipLoadingOnRefresh: false,
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar los equipos',
                error: error,
                onRetry: () => ref.invalidate(teamsPeriodSummaryProvider),
              ),
              data: (summary) => FadeIn(
                child: _TeamsOverviewContent(
                  summary: summary,
                  filteredTeamsAsync: filteredTeamsAsync,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamsOverviewContent extends ConsumerWidget {
  final TeamsPeriodSummary summary;
  final AsyncValue<List<TeamOverview>> filteredTeamsAsync;

  const _TeamsOverviewContent({
    required this.summary,
    required this.filteredTeamsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = summary.teams;
    final selectedScope = ref.watch(periodFilterProvider).scope;
    final selectedMonth = ref.watch(periodFilterProvider).month;
    final selectedYear = ref.watch(periodFilterProvider).year;

    return ListView(
      padding: screenPadding,
      children: [
        Text(
          'Vista general',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          summary.hasData
              ? 'Seguimiento del avance de ${teams.length} equipos de formación.'
              : 'Seleccioná un período con datos cargados.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        const PeriodFilterPanel(),
        const SizedBox(height: 22),
        if (!summary.hasData)
          EmptyDataState.periodWithoutData(
            icon: Icons.groups_outlined,
            period: periodLabel(selectedScope, selectedMonth, selectedYear),
          )
        else if (teams.isEmpty)
          const EmptyDataState(
            icon: Icons.groups_outlined,
            title:
                'No hay equipos con colaboradores elegibles en este período.',
            message:
                'Verificá la nómina elegible para el período seleccionado.',
          )
        else ...[
          TeamsKpiSection(
            teamCount: summary.teamCount,
            employeeCount: summary.employeeCount,
            completedHours: summary.completedHours,
            targetHours: summary.targetHours,
            overallCompletion: summary.overallCompletion,
            isAnnual: selectedScope == PeriodScope.annual,
            year: selectedYear,
            month: selectedMonth,
            variation: ref
                .watch(complianceVariationProvider((area: null, team: null)))
                .value,
            projection: ref
                .watch(annualProjectionProvider((area: null, team: null)))
                .value,
          ),
          const SizedBox(height: 16),
          _TeamsChartsRow(
            statusChart: TeamsStatusSummary(
              total: summary.teamCount,
              onTarget: summary.onTarget,
              atRisk: summary.atRisk,
              critical: summary.critical,
            ),
            categoryChart: TeamCategoryDistribution(
              businessHours: summary.businessHours,
              softSkillsHours: summary.softSkillsHours,
              explorationHours: summary.explorationHours,
              teachingHours: summary.teachingHours,
              isAnnual: selectedScope == PeriodScope.annual,
            ),
          ),

          if (ref.watch(teamComplianceProvider).value case final items?
              when items.isNotEmpty) ...[
            const SizedBox(height: 16),
            MoodleCrmComparisonCards(complianceList: items),
          ],
          const SizedBox(height: 24),
          FilterBar(
            scope: DataFilterScope.teams,
            rows: ref.watch(teamFilterRowsProvider),
          ),
          const SizedBox(height: 24),
          filteredTeamsAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                color: context.colorScheme.primary,
              ),
            ),
            error: (error, _) => ErrorDataState(
              title: 'No pudimos cargar los equipos',
              error: error,
              onRetry: () => ref.invalidate(filteredTeamOverviewsProvider),
            ),
            data: (filteredTeams) => TeamResults(
              key: ValueKey(
                '$selectedScope-$selectedYear-$selectedMonth-'
                '${ref.watch(dataFilterSelectionProvider(DataFilterScope.teams)).values}',
              ),
              teams: filteredTeams,
              teamCount: summary.teamCount,
              isAnnual: selectedScope == PeriodScope.annual,
            ),
          ),
        ],
      ],
    );
  }
}

class _TeamsChartsRow extends StatelessWidget {
  static const _horizontalChartsBreakpoint = 1180.0;
  final Widget statusChart;
  final Widget categoryChart;

  const _TeamsChartsRow({
    required this.statusChart,
    required this.categoryChart,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _horizontalChartsBreakpoint) {
          return Column(
            children: [statusChart, const SizedBox(height: 16), categoryChart],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: statusChart),
              const SizedBox(width: 16),
              Expanded(child: categoryChart),
            ],
          ),
        );
      },
    );
  }
}
