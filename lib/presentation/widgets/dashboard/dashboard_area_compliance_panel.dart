import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardAreaCompliancePanel extends StatelessWidget {
  final AsyncValue<List<SemaforoAreaViewModel>> areasAsync;

  const DashboardAreaCompliancePanel({super.key, required this.areasAsync});

  @override
  Widget build(BuildContext context) {
    return areasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Error: $error'),
      data: (areas) {
        if (areas.isEmpty) return const SizedBox.shrink();

        final sortedAreas = [...areas]
          ..sort(
            (first, second) => second.porcentajeCumplimiento.compareTo(
              first.porcentajeCumplimiento,
            ),
          );
        return _AreaComplianceCard(areas: sortedAreas);
      },
    );
  }
}

class _AreaComplianceCard extends StatelessWidget {
  final List<SemaforoAreaViewModel> areas;

  const _AreaComplianceCard({required this.areas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: context.panel(sombra: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cumplimiento por área',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Progreso relativo respecto a la meta institucional de 8 h',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${areas.length} áreas',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < areas.length; index++) ...[
            _AreaProgressRow(area: areas[index]),
            if (index != areas.length - 1) const SizedBox(height: 12),
          ],
          Divider(height: 22, color: context.colorScheme.outlineVariant),
          Row(
            children: [
              Expanded(
                child: Text(
                  _panelMessage(areas),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/areas?origen=dashboard'),
                icon: const Icon(Icons.arrow_forward, size: 13),
                label: const Text('Ver áreas'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colorScheme.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _panelMessage(List<SemaforoAreaViewModel> areas) {
    final lowest = areas.last;
    if (lowest.porcentajeCumplimiento < 70) {
      return '${lowest.area} requiere refuerzo en el tramo final del mes';
    }
    return 'Todas las áreas se encuentran en seguimiento';
  }
}

class _AreaProgressRow extends StatelessWidget {
  final SemaforoAreaViewModel area;

  const _AreaProgressRow({required this.area});

  @override
  Widget build(BuildContext context) {
    final progress = (area.porcentajeCumplimiento / 100).clamp(0.0, 1.0);
    final color = area.semaforo.colores(context).texto;
    final label =
        '${formatearPorcentaje(area.porcentajeCumplimiento)} · ${area.horasCompletadas.toStringAsFixed(1)} h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: area.area,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(
                      text: ' (${area.cantidadColaboradores} p.)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: area.semaforo.colores(context).fondo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: context.colores.graficoPista,
            color: color,
          ),
        ),
      ],
    );
  }
}
