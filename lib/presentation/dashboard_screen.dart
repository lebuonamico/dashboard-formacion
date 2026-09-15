/*
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cumplimientoAsync = ref.watch(cumplimientoGlobalProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                // TopBar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Plan Q3 - Formación Interna',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0D53C3),
                        child: const Text('U', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),

                // Contenido principal
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: cumplimientoAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                      data: (cumplimientos) {
                        if (cumplimientos.isEmpty) {
                          return const Center(child: Text('No hay datos registrados.'));
                        }

                        final totalEmpleados = cumplimientos.length;
                        final empleadosCumplen =
                            cumplimientos.where((c) => c.cumpleObjetivo).length;
                        final promedioCumplimiento = cumplimientos
                                .map((c) => c.porcentajeTotal)
                                .reduce((a, b) => a + b) /
                            totalEmpleados;

                        return ListView(
                          children: [
                            // Tarjetas de Métricas (KPIs)
                            Row(
                              children: [
                                Expanded(
                                  child: _KpiCard(
                                    title: 'Total Colaboradores',
                                    value: '$totalEmpleados',
                                    icon: Icons.people_outline,
                                    iconColor: const Color(0xFF0D53C3),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _KpiCard(
                                    title: 'Objetivo Cumplido (Q3)',
                                    value: '$empleadosCumplen / $totalEmpleados',
                                    icon: Icons.task_alt,
                                    iconColor: const Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _KpiCard(
                                    title: 'Progreso Promedio',
                                    value: '${promedioCumplimiento.toStringAsFixed(1)}%',
                                    icon: Icons.donut_large,
                                    iconColor: const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Lista de Empleados
                            const Text(
                              'Cumplimiento por Colaborador',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildCardEmpleados(context, cumplimientos),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardEmpleados(BuildContext context, List<CumplimientoEmpleado> cumplimientos) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cumplimientos.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final item = cumplimientos[index];
          final emp = item.empleado;

          return ExpansionTile(
            shape: const Border(),
            leading: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/empleados/${emp.legajo}'),
              child: CircleAvatar(
                backgroundColor: item.cumpleObjetivo
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                child: Icon(
                  item.cumpleObjetivo ? Icons.check : Icons.access_time,
                  color: item.cumpleObjetivo
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  size: 20,
                ),
              ),
            ),
            title: InkWell(
              onTap: () => context.push('/empleados/${emp.legajo}'),
              child: Row(
                children: [
                  Text(
                    '${emp.nombre} ${emp.apellido}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.open_in_new, size: 14, color: Color(0xFF64748B)),
                ],
              ),
            ),
            subtitle: Text(
              '${emp.seniority.label} · ${emp.area} (${emp.legajo})',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            trailing: SizedBox(
              width: 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.totalHorasCompletadas.toStringAsFixed(0)} / ${item.totalHorasRequeridas.toStringAsFixed(0)} hs',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.porcentajeTotal / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: item.cumpleObjetivo
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  children: TipoCurso.values.map((tipo) {
                    final completadas = item.horasCompletadas[tipo] ?? 0.0;
                    final requeridas = item.horasRequeridas[tipo] ?? 0.0;
                    final cumpleTipo = completadas >= requeridas;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tipo.label,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                          ),
                          Text(
                            '${completadas.toStringAsFixed(0)} / ${requeridas.toStringAsFixed(0)} hs',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cumpleTipo
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cumplimientoAsync = ref.watch(cumplimientoGlobalProvider);
    final areasAsync = ref.watch(semaforoPorAreaProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                // TopBar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Plan Q3 - Formación Interna',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0D53C3),
                        child: const Text('U', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),

                // Contenido principal
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ListView(
                      children: [
                        // KPIs Generales en Grilla (3 por fila, los nuevos bajan solos)
                        cumplimientoAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(child: Text('Error: $err')),
                          data: (cumplimientos) {
                            if (cumplimientos.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final totalEmpleados = cumplimientos.length;
                            final empleadosCumplen =
                                cumplimientos.where((c) => c.cumpleObjetivo).length;
                            final promedioCumplimiento = cumplimientos
                                    .map((c) => c.porcentajeTotal)
                                    .reduce((a, b) => a + b) /
                                totalEmpleados;

                            final totalHorasCargadas = cumplimientos.fold<double>(
                                0.0, (acc, c) => acc + c.totalHorasCompletadas);
                            final totalHorasRequeridas = cumplimientos.fold<double>(
                                0.0, (acc, c) => acc + c.totalHorasRequeridas);

                            final kpiCards = [
                              _KpiCard(
                                title: 'Total Colaboradores',
                                value: '$totalEmpleados',
                                subtitle: 'Nómina activa asignada',
                                icon: Icons.people_outline,
                                iconColor: const Color(0xFF0D53C3),
                              ),
                              _KpiCard(
                                title: 'Horas Totales Cargadas',
                                value: '${totalHorasCargadas.toStringAsFixed(0)} hs',
                                subtitle: 'Meta: ${totalHorasRequeridas.toStringAsFixed(0)} hs plan',
                                icon: Icons.access_time_rounded,
                                iconColor: const Color(0xFF7C3AED),
                              ),
                              _KpiCard(
                                title: 'Objetivo Cumplido (Q3)',
                                value: '$empleadosCumplen / $totalEmpleados',
                                subtitle: '${((empleadosCumplen / totalEmpleados) * 100).toStringAsFixed(0)}% del equipo en meta',
                                icon: Icons.task_alt,
                                iconColor: const Color(0xFF16A34A),
                              ),
                              _KpiCard(
                                title: 'Progreso Promedio',
                                value: '${promedioCumplimiento.toStringAsFixed(1)}%',
                                subtitle: 'Rendimiento general consolidado',
                                icon: Icons.donut_large,
                                iconColor: const Color(0xFFD97706),
                              ),
                            ];

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 105,
                              ),
                              itemCount: kpiCards.length,
                              itemBuilder: (context, index) => kpiCards[index],
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Encabezado de la Sección de Equipos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Estado de Cumplimiento por Equipos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => context.push('/equipos'),
                              icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF0D53C3)),
                              label: const Text(
                                'Ver todos los equipos',
                                style: TextStyle(color: Color(0xFF0D53C3), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Grilla de Semáforos por Equipo (3 por fila, clickables hacia /equipos/:area)
                        areasAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(child: Text('Error: $err')),
                          data: (areas) {
                            if (areas.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Center(child: Text('No hay equipos registrados.')),
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 130,
                              ),
                              itemCount: areas.length,
                              itemBuilder: (context, index) {
                                final area = areas[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => context.push('/equipos/${Uri.encodeComponent(area.area)}'),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: area.semaforo.colorFondo,
                                          child: Icon(Icons.circle, color: area.semaforo.colorTexto, size: 16),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      area.area,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 15,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${area.horasCompletadas.toStringAsFixed(0)} / ${area.horasRequeridas.toStringAsFixed(0)} hs (${area.porcentajeCumplimiento.toStringAsFixed(0)}%)',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: area.semaforo.colorFondo,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  area.semaforo.label,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: area.semaforo.colorTexto,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;

  const _KpiCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}