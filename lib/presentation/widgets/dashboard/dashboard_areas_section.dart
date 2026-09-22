import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardAreasSection extends ConsumerWidget {
  final AsyncValue<List<SemaforoAreaViewModel>> areasAsync;

  const DashboardAreasSection({super.key, required this.areasAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equiposAsync = ref.watch(equiposGlobalProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Estado de Cumplimiento por Áreas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/areas'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver todas las áreas'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D53C3),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        areasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Error: $error'),
          data: (areas) {
            if (areas.isEmpty) return const _EmptyAreasState();

            return equiposAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
              data: (equipos) {
                final equiposPorArea = <String, int>{};
                for (final equipo in equipos) {
                  equiposPorArea.update(
                    equipo.area,
                    (cantidad) => cantidad + 1,
                    ifAbsent: () => 1,
                  );
                }

                return LayoutBuilder(
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
                      itemBuilder: (context, index) {
                        final area = areas[index];
                        return DashboardAreaCard(
                          area: area,
                          cantidadEquipos: equiposPorArea[area.area] ?? 0,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/areas/${Uri.encodeComponent(area.area)}'),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x090F172A),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: area.semaforo.colorTexto,
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
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${area.cantidadColaboradores} colaboradores',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D53C3),
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
                          const Icon(
                            Icons.people_outline,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${area.cantidadColaboradores} colaboradores · $cantidadEquipos equipos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cumplimiento del área',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '${area.porcentajeCumplimiento.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: area.semaforo.colorTexto,
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
                          backgroundColor: const Color(0xFFEAECF0),
                          color: area.semaforo.colorTexto,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Text(
                            '${area.horasCompletadas.toStringAsFixed(1)} de ${area.horasRequeridas.toStringAsFixed(1)} hs',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Ver detalle',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D53C3),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: Color(0xFF0D53C3),
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
        color: status.colorFondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.colorTexto,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.colorTexto,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(child: Text('No hay áreas registradas.')),
    );
  }
}
