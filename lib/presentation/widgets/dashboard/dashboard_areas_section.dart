import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_bar.dart';
import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardAreasSection extends ConsumerWidget {
  final AsyncValue<List<SemaforoAreaViewModel>> areasAsync;

  const DashboardAreasSection({super.key, required this.areasAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Conservar filtros aunque el cambio de período desmonte esta sección.
    final selection = ref.watch(dataFilterSelectionProvider('dashboard_areas'));
    final equiposAsync = ref.watch(teamOverviewsProvider);

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
                  _buildFilterBar(areas, ref, selection),
                  const SizedBox(height: 16),
                  const _EmptyAreasState(),
                ],
              );
            }

            final areasFiltradas = areas
                .where(
                  (area) => matchesDataFilters(selection, _filterRow(area)),
                )
                .toList();

            return equiposAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar las áreas',
                error: error,
                compact: true,
              ),
              data: (equipos) {
                final equiposPorArea = <String, int>{};
                for (final equipo in equipos) {
                  equiposPorArea.update(
                    equipo.area,
                    (cantidad) => cantidad + 1,
                    ifAbsent: () => 1,
                  );
                }

                return Column(
                  children: [
                    _buildFilterBar(areas, ref, selection),
                    const SizedBox(height: 16),
                    if (areasFiltradas.isEmpty)
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
                            itemCount: areasFiltradas.length,
                            itemBuilder: (context, index) {
                              final area = areasFiltradas[index];
                              return DashboardAreaCard(
                                area: area,
                                cantidadEquipos: equiposPorArea[area.area] ?? 0,
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

  FilterRow _filterRow(SemaforoAreaViewModel area) => {
    'Área': area.area,
    'Estado': area.semaforo.label,
  };

  Widget _buildFilterBar(
    List<SemaforoAreaViewModel> areas,
    WidgetRef ref,
    DataFilterValues selection,
  ) => FilterBar(
    rows: areas.map(_filterRow).toList(),
    selection: selection,
    hasActiveFilters: selection.isNotEmpty,
    onSelectionChanged: (dimension, values) => ref
        .read(dataFilterSelectionProvider('dashboard_areas').notifier)
        .select(dimension, values),
    onClear: () => ref
        .read(dataFilterSelectionProvider('dashboard_areas').notifier)
        .clear(),
  );
}

class DashboardAreaCard extends StatelessWidget {
  final SemaforoAreaViewModel area;
  final int cantidadEquipos;

  const DashboardAreaCard({
    super.key,
    required this.area,
    required this.cantidadEquipos,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (area.porcentajeCumplimiento / 100).clamp(0.0, 1.0);

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(
          '/areas/${Uri.encodeComponent(area.area)}?origen=dashboard',
        ),
        child: Container(
          decoration: context.panel(sombra: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: area.semaforo.colores(context).texto,
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
                                  '${area.cantidadColaboradores} colaboradores',
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
                          _AreaStatusBadge(status: area.semaforo),
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
                              '${area.cantidadColaboradores} colaboradores · $cantidadEquipos equipos',
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
                            formatearPorcentaje(area.porcentajeCumplimiento),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: area.semaforo.colores(context).texto,
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
                          backgroundColor: context.colores.graficoPista,
                          color: area.semaforo.colores(context).texto,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Text(
                            '${area.horasCompletadas.toStringAsFixed(1)} de ${area.horasRequeridas.toStringAsFixed(1)} hs',
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
  final EstadoSemaforo status;

  const _AreaStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.colores(context).fondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.colores(context).texto,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.colores(context).texto,
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
