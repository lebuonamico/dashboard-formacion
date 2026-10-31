import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/area_compliance_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/status_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardAreasSection extends ConsumerWidget {
  final AsyncValue<List<AreaComplianceViewModel>> areasAsync;

  const DashboardAreasSection({super.key, required this.areasAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Conservar filtros aunque el cambio de período desmonte esta sección.
    final selection = ref
        .watch(dataFilterSelectionProvider(DataFilterScope.dashboardAreas))
        .values;
    final filters = ref.watch(dataFilterServiceProvider);
    final teamsAsync = ref.watch(teamOverviewsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Estado de cumplimiento por áreas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/areas?origen=dashboard'),
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
        areasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorDataState(
            title: 'No pudimos cargar las áreas',
            error: error,
            compact: true,
          ),
          data: (areas) {
            if (areas.isEmpty) {
              return Column(
                children: [
                  _AreasFilterBar(rows: areas.map(_filterRow).toList()),
                  const SizedBox(height: 16),
                  const _EmptyAreasState(),
                ],
              );
            }

            final filteredAreas = areas
                .where((area) => filters.matches(selection, _filterRow(area)))
                .toList();

            return teamsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar las áreas',
                error: error,
                compact: true,
              ),
              data: (teams) {
                final teamsByArea = <String, int>{};
                for (final team in teams) {
                  teamsByArea.update(
                    team.area,
                    (count) => count + 1,
                    ifAbsent: () => 1,
                  );
                }

                return Column(
                  children: [
                    _AreasFilterBar(rows: areas.map(_filterRow).toList()),
                    const SizedBox(height: 16),
                    if (filteredAreas.isEmpty)
                      const _EmptyFilteredAreasState()
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 600
                              ? 2
                              : 1;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 230,
                                ),
                            itemCount: filteredAreas.length,
                            itemBuilder: (context, index) {
                              final area = filteredAreas[index];
                              return DashboardAreaCard(
                                area: area,
                                teamCount: teamsByArea[area.area] ?? 0,
                              );
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  FilterRow _filterRow(AreaComplianceViewModel area) =>
      FilterRow({'Área': area.area, 'Estado': area.level.label});
}

class _AreasFilterBar extends StatelessWidget {
  final List<FilterRow> rows;

  const _AreasFilterBar({required this.rows});

  @override
  Widget build(BuildContext context) => FilterBar(
    scope: DataFilterScope.dashboardAreas,
    rows: AsyncValue.data(rows),
  );
}

class DashboardAreaCard extends StatelessWidget {
  final AreaComplianceViewModel area;
  final int teamCount;

  const DashboardAreaCard({
    super.key,
    required this.area,
    required this.teamCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (area.compliancePercentage / 100).clamp(0.0, 1.0);

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(
          '/areas/${Uri.encodeComponent(area.area)}?origen=dashboard',
        ),
        child: Container(
          decoration: context.panel(shadow: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: area.level.colors(context).text,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  area.area,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: context.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${area.employeeCount} colaboradores',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AreaStatusBadge(status: area.level),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 16,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${area.employeeCount} colaboradores · $teamCount equipos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cumplimiento del área',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            formatPercentage(area.compliancePercentage),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: area.level.colors(context).text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: context.colors.chartTrack,
                          color: area.level.colors(context).text,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Text(
                            '${area.completedHours.toStringAsFixed(1)} de ${area.requiredHours.toStringAsFixed(1)} hs',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Ver detalle',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: context.colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaStatusBadge extends StatelessWidget {
  final ComplianceLevel status;

  const _AreaStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.colors(context).background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.colors(context).text,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.colors(context).text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
