import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/side_by_side_charts.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_category_distribution.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_kpi_section.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_results.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_status_summary.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/moodle_crm_comparison_cards.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';

class AreasScreen extends ConsumerWidget {
  const AreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(areasPeriodSummaryProvider);
    final filteredAreasAsync = ref.watch(filteredAreasProvider);

    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          const AppTopBar(title: 'Áreas y equipos generales'),
          Expanded(
            child: summaryAsync.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: true,
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar las áreas',
                error: error,
                onRetry: () => ref.invalidate(areasPeriodSummaryProvider),
              ),
              data: (summary) => FadeIn(
                child: _AreasContent(
                  summary: summary,
                  filteredAreasAsync: filteredAreasAsync,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreasContent extends ConsumerWidget {
  final AreasPeriodSummary summary;
  final AsyncValue<List<AreaSummary>> filteredAreasAsync;

  const _AreasContent({
    required this.summary,
    required this.filteredAreasAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = summary.areas;
    final selectedScope = ref.watch(periodFilterProvider).scope;
    final selectedMonth = ref.watch(periodFilterProvider).month;
    final selectedYear = ref.watch(periodFilterProvider).year;
    final isAnnual = selectedScope == PeriodScope.annual;

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
              ? 'Seguimiento del cumplimiento de '
                    '${countLabel(areas.length, 'área', 'áreas')}.'
              : 'Seleccioná un período con datos cargados.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        const PeriodFilterPanel(
          included:
              'Se incluyen todas las áreas con colaboradores elegibles al '
              'cierre, aunque tengan 0 horas.',
        ),
        const SizedBox(height: 22),
        if (!summary.hasData)
          EmptyDataState.periodWithoutData(
            icon: Icons.apartment_outlined,
            period: periodLabel(selectedScope, selectedMonth, selectedYear),
          )
        else if (areas.isEmpty)
          const EmptyDataState(
            icon: Icons.apartment_outlined,
            title: 'No hay áreas con colaboradores elegibles en este período.',
            message:
                'Verificá los colaboradores elegibles del período seleccionado.',
          )
        else ...[
          AreasKpiSection(
            totalAreas: summary.areaCount,
            totalEmployees: summary.employeeCount,
            completedHours: summary.completedHours,
            targetHours: summary.targetHours,
            complianceGlobal: summary.overallCompletion,
            isAnnual: isAnnual,
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
          SideBySideCharts(
            first: AreasStatusSummary(
              total: summary.areaCount,
              onTarget: summary.onTarget,
              atRisk: summary.atRisk,
              critical: summary.critical,
            ),
            second: AreasCategoryDistribution(
              businessHours: summary.businessHours,
              softSkillsHours: summary.softSkillsHours,
              explorationHours: summary.explorationHours,
              teachingHours: summary.teachingHours,
              isAnnual: isAnnual,
            ),
          ),
          // Moodle vs CRM of every area, with the same employees as the summary.
          if (ref.watch(teamComplianceProvider).value case final items?
              when items.isNotEmpty) ...[
            const SizedBox(height: 16),
            MoodleCrmComparisonCards(complianceList: items),
          ],
          const SizedBox(height: 24),
          FilterBar(
            scope: DataFilterScope.areas,
            rows: ref.watch(areaFilterRowsProvider),
          ),
          const SizedBox(height: 24),
          filteredAreasAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                color: context.colorScheme.primary,
              ),
            ),
            error: (error, _) => ErrorDataState(
              title: 'No pudimos cargar las áreas',
              error: error,
              onRetry: () => ref.invalidate(filteredAreasProvider),
            ),
            data: (filteredAreas) => AreasResults(
              key: ValueKey(
                '$selectedScope-$selectedYear-$selectedMonth-'
                '${ref.watch(dataFilterSelectionProvider(DataFilterScope.areas)).values}',
              ),
              areas: filteredAreas,
              totalAreas: summary.areaCount,
              isAnnual: isAnnual,
            ),
          ),
        ],
      ],
    );
  }
}
