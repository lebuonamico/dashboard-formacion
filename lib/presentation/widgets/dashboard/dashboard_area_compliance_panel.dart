import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter/material.dart';
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cumplimiento por Área',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Progreso relativo respecto a la meta institucional de 8 h',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${areas.length} áreas',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
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
          const Divider(height: 22, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              Expanded(
                child: Text(
                  _panelMessage(areas),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/areas'),
                icon: const Icon(Icons.arrow_forward, size: 13),
                label: const Text('Ver áreas'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
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
    final color = area.semaforo.colorTexto;
    final label =
        '${area.porcentajeCumplimiento.toStringAsFixed(0)}% · ${area.horasCompletadas.toStringAsFixed(1)} h';

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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: ' (${area.cantidadColaboradores} p.)',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
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
                color: area.semaforo.colorFondo,
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
            backgroundColor: const Color(0xFFE5ECFA),
            color: color,
          ),
        ),
      ],
    );
  }
}
