import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:app_finnegans/presentation/widgets/shared/etiqueta_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';


class MetricasScreen extends ConsumerWidget {
  const MetricasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(kpisGeneralesMetricasProvider);
    final seniorityAsync = ref.watch(cumplimientoPorSeniorityProvider);
    final areaAsync = ref.watch(semaforoPorAreaProvider);
    final instructoresAsync = ref.watch(metricasInstructoresProvider);

    final estiloSeccion = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: context.colorScheme.onSurface,
    );

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Tablero de métricas y KPI de formación'),

          // Contenido
          Expanded(
            child: ListView(
              padding: paddingPantalla,
              children: [
                // 1. Tarjetas de KPIs Generales
                kpisAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (kpis) => _buildKpiRow(context, kpis),
                ),
                const SizedBox(height: 24),

                // 2. Semáforos por Equipo / Área
                Text(
                  'Semáforo de cumplimiento por equipo',
                  style: estiloSeccion,
                ),
                const SizedBox(height: 12),
                areaAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (areas) => _buildSemaforoAreasGrid(areas),
                ),
                const SizedBox(height: 24),

                // 3. Matriz de Cumplimiento y Desvíos por Seniority
                Text(
                  'Cumplimiento y desvíos por seniority y categoría',
                  style: estiloSeccion,
                ),
                const SizedBox(height: 12),
                seniorityAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (seniorities) =>
                      _buildTablaDesviosSeniority(context, seniorities),
                ),
                const SizedBox(height: 24),

                // 4. Formación Impartida: Variedad y Horas de Dictado
                Text(
                  'Seguimiento de formadores (variedad y dictado)',
                  style: estiloSeccion,
                ),
                const SizedBox(height: 12),
                instructoresAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (instructores) =>
                      _buildTablaInstructores(context, instructores),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(BuildContext context, KpisGeneralesViewModel kpis) {
    return Row(
      children: [
        Expanded(
          child: _KpiMetricCard(
            title: '% de Finnencers alcanzados',
            value: '${kpis.porcentajeFinnencersAlcanzados.toStringAsFixed(1)}%',
            subtitle:
                '${kpis.totalFinnencersAlcanzados} de ${kpis.totalNomina} nómina',
            icon: Icons.groups_outlined,
            iconColor: context.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiMetricCard(
            title: 'Proyección anual de la nómina',
            value: '${kpis.proyectadoAnualPromedio.toStringAsFixed(0)} hs/año',
            subtitle:
                'Objetivo meta: ${kpis.horasRequeridasAnuales.toStringAsFixed(0)} hs/persona',
            icon: Icons.trending_up,
            iconColor:
                kpis.proyectadoAnualPromedio >= kpis.horasRequeridasAnuales
                ? context.colores.exito.texto
                : context.colores.advertencia.texto,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiMetricCard(
            title: 'Horas de dictado acumuladas',
            value: '${kpis.totalHorasDictadas.toStringAsFixed(0)} hs',
            subtitle: 'Capacitaciones internas impartidas',
            icon: Icons.record_voice_over_outlined,
            iconColor: context.colores.acentoVioleta,
          ),
        ),
      ],
    );
  }

  Widget _buildSemaforoAreasGrid(List<SemaforoAreaViewModel> areas) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 110,
      ),
      itemCount: areas.length,
      itemBuilder: (context, index) {
        final area = areas[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: context.panel(),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: area.semaforo.colores(context).fondo,
                child: Icon(
                  Icons.circle,
                  color: area.semaforo.colores(context).texto,
                  size: 16,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      area.area,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${area.horasCompletadas.toStringAsFixed(0)} / ${area.horasRequeridas.toStringAsFixed(0)} hs (${formatearPorcentaje(area.porcentajeCumplimiento)})',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      area.semaforo.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: area.semaforo.colores(context).texto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTablaDesviosSeniority(
    BuildContext context,
    List<SeniorityMetricaViewModel> seniorities,
  ) {
    return Container(
      decoration: context.panel(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              context.colorScheme.surfaceContainerLow,
            ),
            columns: const [
              DataColumn(
                label: Text(
                  'Seniority',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Nómina',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Horas realizadas / plan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Cumplimiento',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Estado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Desvíos por categoría',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: seniorities.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      item.seniority.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(Text('${item.cantidadEmpleados} pers.')),
                  DataCell(
                    Text(
                      '${item.totalHorasRealizadas.toStringAsFixed(0)} / ${item.totalHorasRequeridas.toStringAsFixed(0)} hs',
                    ),
                  ),
                  DataCell(
                    Text(formatearPorcentaje(item.porcentajeCumplimiento)),
                  ),
                  DataCell(
                    EtiquetaColor(
                      texto: item.semaforo.label,
                      colores: item.semaforo.colores(context),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: item.desviosPorCategoria.map((d) {
                        final desvio = d.desvio;
                        final esNegativo = desvio < 0;
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: esNegativo
                                ? context.colores.peligro.fondo
                                : context.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${d.tipo.name.substring(0, 3).toUpperCase()}: ${esNegativo ? "" : "+"}${desvio.toStringAsFixed(0)}h',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: esNegativo
                                  ? context.colores.peligro.texto
                                  : context.colores.textoIntermedio,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTablaInstructores(
    BuildContext context,
    List<InstructorMetricaViewModel> instructores,
  ) {
    if (instructores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: context.panel(),
        child: const Center(
          child: Text('No hay formadores registrados con horas impartidas.'),
        ),
      );
    }

    return Container(
      decoration: context.panel(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStatePropertyAll(
              context.colorScheme.surfaceContainerLow,
            ),
            columns: const [
              DataColumn(
                label: Text(
                  'Instructor',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Área / equipo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Seniority',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Variedad (cursos distintos)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Horas impartidas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Acción',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: instructores.map((inst) {
              return DataRow(
                onSelectChanged: (_) =>
                    _mostrarDetalleCursosDictados(context, inst),
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: context.colorScheme.outlineVariant,
                          child: Text(
                            inst.nombreCompleto.substring(0, 1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          inst.nombreCompleto,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(inst.area)),
                  DataCell(Text(inst.seniority.label)),
                  DataCell(
                    EtiquetaColor(
                      texto: '${inst.variedadCursosDistintos} temas distintos',
                      colores: ParColores(
                        context.colorScheme.onPrimaryContainer,
                        context.colorScheme.primaryContainer,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${inst.totalHorasDictadas.toStringAsFixed(0)} hs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: context.colorScheme.primary,
                      ),
                      tooltip: 'Ver detalle de cursos',
                      onPressed: () =>
                          _mostrarDetalleCursosDictados(context, inst),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleCursosDictados(
    BuildContext context,
    InstructorMetricaViewModel inst,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 500),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inst.nombreCompleto,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${inst.area} · ${inst.seniority.label} (Legajo: ${inst.legajo})',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Total impartido: ${inst.totalHorasDictadas.toStringAsFixed(0)} hs',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '(${inst.variedadCursosDistintos} formaciones distintas)',
                        style: TextStyle(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: inst.cursosDictados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = inst.cursosDictados[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: context.panel().copyWith(
                            color: context.colorScheme.surfaceContainerLow,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.nombre,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: context.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${c.clasificacion.label} · Área: ${c.areaCurso}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              EtiquetaColor(
                                texto:
                                    '${c.cargaHorariaHs.toStringAsFixed(0)} hs',
                                colores: context.colores.dictado,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _KpiMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.panel(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colores.textoIntermedio,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorScheme.onSurfaceVariant,
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
