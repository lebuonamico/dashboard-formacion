import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';

// Filtro local de estado para los miembros del equipo
final filtroEstadoMiembroProvider = StateProvider.autoDispose<String?>((ref) => null);

class AreaDetalleScreen extends ConsumerWidget {
  final String nombreArea;

  const AreaDetalleScreen({super.key, required this.nombreArea});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(detalleEquipoProvider(nombreArea));
    final filtroEstado = ref.watch(filtroEstadoMiembroProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                // TopBar con navegación hacia atrás
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Área: $nombreArea',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido
                Expanded(
                  child: detalleAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                    data: (detalle) {
                      final res = detalle.resumen;
                      final miembros = detalle.miembros;

                      // Filtrado dinámico de la tabla
                      final miembrosVisibles = miembros.where((m) {
                        if (filtroEstado == 'cumplido') return m.porcentajeTotal >= 100.0;
                        if (filtroEstado == 'riesgo') return m.porcentajeTotal >= 70.0 && m.porcentajeTotal < 100.0;
                        if (filtroEstado == 'critico') return m.porcentajeTotal < 70.0;
                        return true;
                      }).toList();

                      return ListView(
                        padding: const EdgeInsets.all(24.0),
                        children: [
                          _buildAreaSummary(context, res, detalle.miembrosPorEquipo),
                          const SizedBox(height: 24),

                          // Barra de Filtros de la Tabla
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Integrantes (${miembrosVisibles.length})',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              Row(
                                children: [
                                  _buildFilterChip(ref, 'Todos', null, filtroEstado == null),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(ref, 'Cumplidos', 'cumplido', filtroEstado == 'cumplido'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(ref, 'En riesgo', 'riesgo', filtroEstado == 'riesgo'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(ref, 'Críticos', 'critico', filtroEstado == 'critico'),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Tabla de Nómina del Área
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: DataTable(
                                showCheckboxColumn: false,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                columns: const [
                                  DataColumn(label: Text('Legajo', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Colaborador', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Seniority', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Horas Realizadas / Plan', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Progreso', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: miembrosVisibles.map((m) {
                                  final emp = m.empleado;
                                  final cumple = m.cumpleObjetivo;

                                  return DataRow(
                                    onSelectChanged: (_) => context.push('/empleados/${emp.legajo}'),
                                    cells: [
                                      DataCell(Text(emp.legajo, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: const Color(0xFFE2E8F0),
                                              child: Text(
                                                emp.nombre.substring(0, 1),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('${emp.nombre} ${emp.apellido}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.open_in_new, size: 12, color: Color(0xFF94A3B8)),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(emp.seniority.label)),
                                      DataCell(Text('${m.totalHorasCompletadas.toStringAsFixed(0)} / ${m.totalHorasRequeridas.toStringAsFixed(0)} hs')),
                                      DataCell(
                                        SizedBox(
                                          width: 90,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: (m.porcentajeTotal / 100).clamp(0.0, 1.0),
                                              minHeight: 6,
                                              backgroundColor: const Color(0xFFF1F5F9),
                                              color: cumple ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: cumple ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            cumple ? 'Cumplido' : 'Pendiente',
                                            style: TextStyle(
                                              color: cumple ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaSummary(
    BuildContext context,
    ResumenEquipoViewModel resumen,
    Map<String, List<CumplimientoEmpleado>> miembrosPorEquipo,
  ) {
    final equipos = miembrosPorEquipo.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalles del Área',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          '${resumen.cantidadIntegrantes} colaboradores · ${equipos.length} equipos generales',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        if (equipos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text('No hay equipos generales asignados.', style: TextStyle(color: Color(0xFF64748B))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 150,
            ),
            itemCount: equipos.length,
            itemBuilder: (context, index) {
              final entry = equipos[index];
              final cumplidos = entry.value.where((item) => item.cumpleObjetivo).length;
              final porcentaje = entry.value.isEmpty ? 0.0 : (cumplidos / entry.value.length) * 100;
              final color = porcentaje >= 80
                  ? const Color(0xFF16A34A)
                  : porcentaje >= 50
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626);

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/areas/${Uri.encodeComponent(nombreArea)}/equipos/${Uri.encodeComponent(entry.key)}'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.groups_outlined, color: Color(0xFF0D53C3), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(entry.key, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          ),
                          const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                      Text('${entry.value.length} integrantes', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$cumplidos en objetivo', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text('${porcentaje.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                        ],
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: porcentaje / 100, minHeight: 6, color: color, backgroundColor: const Color(0xFFF1F5F9)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String? value, bool seleccionado) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => ref.read(filtroEstadoMiembroProvider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? const Color(0xFF0D53C3) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado ? const Color(0xFF0D53C3) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: seleccionado ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

