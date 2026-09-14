import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
//import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class MetricasScreen extends ConsumerWidget {
  const MetricasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(kpisGeneralesMetricasProvider);
    final seniorityAsync = ref.watch(cumplimientoPorSeniorityProvider);
    final areaAsync = ref.watch(semaforoPorAreaProvider);
    final instructoresAsync = ref.watch(metricasInstructoresProvider);

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
                        'Tablero de Métricas & KPIs de Formación',
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

                // Contenido
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      // 1. Tarjetas de KPIs Generales
                      kpisAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error: $err')),
                        data: (kpis) => _buildKpiRow(kpis),
                      ),
                      const SizedBox(height: 24),

                      // 2. Semáforos por Equipo / Área
                      const Text(
                        'Semáforo de Cumplimiento por Equipo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      areaAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error: $err')),
                        data: (areas) => _buildSemaforoAreasGrid(areas),
                      ),
                      const SizedBox(height: 24),

                      // 3. Matriz de Cumplimiento y Desvíos por Seniority
                      const Text(
                        'Cumplimiento y Desvíos por Seniority y Categoría',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      seniorityAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error: $err')),
                        data: (seniorities) => _buildTablaDesviosSeniority(seniorities),
                      ),
                      const SizedBox(height: 24),

                      // 4. Formación Impartida: Variedad y Horas de Dictado
                      const Text(
                        'Seguimiento de Formadores (Variedad y Dictado)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      instructoresAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error: $err')),
                        data: (instructores) => _buildTablaInstructores(context, instructores),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(KpisGeneralesViewModel kpis) {
    return Row(
      children: [
        Expanded(
          child: _KpiMetricCard(
            title: '% Finnencers Alcanzados',
            value: '${kpis.porcentajeFinnencersAlcanzados.toStringAsFixed(1)}%',
            subtitle: '${kpis.totalFinnencersAlcanzados} de ${kpis.totalNomina} nómina',
            icon: Icons.groups_outlined,
            iconColor: const Color(0xFF0D53C3),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiMetricCard(
            title: 'Proyectado Anual Nómina',
            value: '${kpis.proyectadoAnualPromedio.toStringAsFixed(0)} hs/año',
            subtitle: 'Objetivo meta: ${kpis.horasRequeridasAnuales.toStringAsFixed(0)} hs/persona',
            icon: Icons.trending_up,
            iconColor: kpis.proyectadoAnualPromedio >= kpis.horasRequeridasAnuales
                ? const Color(0xFF16A34A)
                : const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiMetricCard(
            title: 'Horas de Dictado Acumuladas',
            value: '${kpis.totalHorasDictadas.toStringAsFixed(0)} hs',
            subtitle: 'Capacitaciones internas impartidas',
            icon: Icons.record_voice_over_outlined,
            iconColor: const Color(0xFF7C3AED),
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
                    Text(
                      area.area,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${area.horasCompletadas.toStringAsFixed(0)} / ${area.horasRequeridas.toStringAsFixed(0)} hs (${area.porcentajeCumplimiento.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      area.semaforo.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: area.semaforo.colorTexto,
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

  Widget _buildTablaDesviosSeniority(List<SeniorityMetricaViewModel> seniorities) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Seniority', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Nómina', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Horas Realizadas / Plan', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Cumplimiento', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Desvíos por Categoría', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: seniorities.map((item) {
              return DataRow(
                cells: [
                  DataCell(Text(item.seniority.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('${item.cantidadEmpleados} pers.')),
                  DataCell(Text('${item.totalHorasRealizadas.toStringAsFixed(0)} / ${item.totalHorasRequeridas.toStringAsFixed(0)} hs')),
                  DataCell(Text('${item.porcentajeCumplimiento.toStringAsFixed(1)}%')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.semaforo.colorFondo,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.semaforo.label,
                        style: TextStyle(color: item.semaforo.colorTexto, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: item.desviosPorCategoria.map((d) {
                        final desvio = d.desvio;
                        final esNegativo = desvio < 0;
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: esNegativo ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${d.tipo.name.substring(0, 3).toUpperCase()}: ${esNegativo ? "" : "+"}${desvio.toStringAsFixed(0)}h',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: esNegativo ? const Color(0xFFDC2626) : const Color(0xFF334155),
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

  Widget _buildTablaInstructores(BuildContext context, List<InstructorMetricaViewModel> instructores) {
    if (instructores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('No hay formadores registrados con horas impartidas.')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Instructor', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Área / Equipo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Seniority', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Variedad (Cursos Distintos)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Horas Impartidas', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Acción', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: instructores.map((inst) {
              return DataRow(
                onSelectChanged: (_) => _mostrarDetalleCursosDictados(context, inst),
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            inst.nombreCompleto.substring(0, 1),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(inst.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  DataCell(Text(inst.area)),
                  DataCell(Text(inst.seniority.label)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${inst.variedadCursosDistintos} temas distintos',
                        style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${inst.totalHorasDictadas.toStringAsFixed(0)} hs',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0D53C3)),
                      tooltip: 'Ver detalle de cursos',
                      onPressed: () => _mostrarDetalleCursosDictados(context, inst),
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

  void _mostrarDetalleCursosDictados(BuildContext context, InstructorMetricaViewModel inst) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${inst.area} · ${inst.seniority.label} (Legajo: ${inst.legajo})',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '(${inst.variedadCursosDistintos} formaciones distintas)',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: inst.cursosDictados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = inst.cursosDictados[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${c.tipo.label} · Área: ${c.areaCurso}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${c.cargaHorariaHs.toStringAsFixed(0)} hs',
                                  style: const TextStyle(
                                    color: Color(0xFFC2410C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}