import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/widgets/summary_card/status_badge.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card_footer.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card_header.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_info_row.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_progress.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_labels.dart';

class DashboardAreasSection extends ConsumerWidget {
  const DashboardAreasSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Estado de cumplimiento por áreas',
                style: context.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/areas'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver todas las áreas'),
              style: TextButton.styleFrom(
                foregroundColor: context.colorScheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilterBar(
          scope: DataFilterScope.dashboardAreas,
          rows: ref.watch(dashboardAreaFilterRowsProvider),
        ),
        const SizedBox(height: 16),
        ref
            .watch(dashboardAreasProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar las áreas',
                error: error,
                onRetry: () => ref.invalidate(dashboardAreasProvider),
                compact: true,
              ),
              data: (areas) => areas.isEmpty
                  ? const _EmptyAreasState()
                  : const _FilteredAreasGrid(),
            ),
      ],
    );
  }
}

class _FilteredAreasGrid extends ConsumerWidget {
  const _FilteredAreasGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(filteredDashboardAreasProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorDataState(
            title: 'No pudimos cargar las áreas',
            error: error,
            onRetry: () => ref.invalidate(filteredDashboardAreasProvider),
            compact: true,
          ),
          data: (areas) => areas.isEmpty
              ? const _EmptyFilteredAreasState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 600
                        ? 2
                        : 1;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 230,
                      ),
                      itemCount: areas.length,
                      itemBuilder: (context, index) => DashboardAreaCard(
                        area: areas[index].area,
                        teamCount: areas[index].teamCount,
                      ),
                    );
                  },
                ),
        );
  }
}

class DashboardAreaCard extends StatelessWidget {
  final AreaSummary area;
  final int teamCount;

  const DashboardAreaCard({
    super.key,
    required this.area,
    required this.teamCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = area.level.colors(context);

    return SummaryCard(
      colors: colors,
      onTap: () => context.push(
        '/areas/${Uri.encodeComponent(area.name)}?origen=dashboard',
      ),
      header: SummaryCardHeader(
        title: area.name,
        subtitle: '${area.memberCount} colaboradores',
        badge: StatusBadge(label: area.level.label, colors: colors),
      ),
      details: [
        SummaryInfoRow(
          icon: Icons.people_outline,
          text: '${area.memberCount} colaboradores · $teamCount equipos',
        ),
      ],
      progress: SummaryProgress(
        caption: 'Cumplimiento del área',
        percentage: area.compliancePercentage,
        colors: colors,
      ),
      footer: SummaryCardFooter(
        completedHours: area.completedHours,
        targetHours: area.targetHours,
        actionLabel: 'Ver detalle',
      ),
    );
  }
}

class _EmptyAreasState extends StatelessWidget {
  const _EmptyAreasState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: context.panel(),
      child: const Center(child: Text('No hay áreas registradas.')),
    );
  }
}

class _EmptyFilteredAreasState extends StatelessWidget {
  const _EmptyFilteredAreasState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: context.panel(),
      child: const Center(
        child: Text('No hay áreas que coincidan con los filtros.'),
      ),
    );
  }
}
