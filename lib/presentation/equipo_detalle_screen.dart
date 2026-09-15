import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';

// Filtro local de estado para los miembros del equipo
final filtroEstadoMiembroProvider = StateProvider.autoDispose<String?>((ref) => null);

class EquipoDetalleScreen extends ConsumerWidget {
  final String nombreArea;

  const EquipoDetalleScreen({super.key, required this.nombreArea});

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
                        'Equipo: $nombreArea',
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

                      // Cálculos para el Gráfico de Torta
                      final enObjetivo = miembros.where((m) => m.porcentajeTotal >= 100.0).length;
                      final enRiesgo = miembros.where((m) => m.porcentajeTotal >= 70.0 && m.porcentajeTotal < 100.0).length;
                      final criticos = miembros.where((m) => m.porcentajeTotal < 70.0).length;

                      // Desglose por categoría formativa
                      final horasPorTipo = <TipoCurso, double>{};
                      for (final m in miembros) {
                        for (final t in TipoCurso.values) {
                          horasPorTipo[t] = (horasPorTipo[t] ?? 0.0) + (m.horasCompletadas[t] ?? 0.0);
                        }
                      }

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
                          // Fila de Tarjetas Superiores: Gráfico de Torta y Distribución Temática
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Gráfico de Torta con Leyenda
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Distribución del Cumplimiento',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 110,
                                            height: 110,
                                            child: CustomPaint(
                                              painter: _PieChartPainter(
                                                valores: [enObjetivo.toDouble(), enRiesgo.toDouble(), criticos.toDouble()],
                                                colores: const [
                                                  Color(0xFF16A34A),
                                                  Color(0xFFD97706),
                                                  Color(0xFFDC2626),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildLegendItem('En objetivo (≥100%)', enObjetivo, const Color(0xFF16A34A)),
                                                const SizedBox(height: 8),
                                                _buildLegendItem('En riesgo (70-99%)', enRiesgo, const Color(0xFFD97706)),
                                                const SizedBox(height: 8),
                                                _buildLegendItem('Crítico (<70%)', criticos, const Color(0xFFDC2626)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // 2. Horas por Categoría Temática
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Carga Realizada por Categoría Temática',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: TipoCurso.values.map((tipo) {
                                          final hs = horasPorTipo[tipo] ?? 0.0;
                                          return Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tipo.label,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${hs.toStringAsFixed(0)} hs',
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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

                          // Tabla de Nómina del Equipo
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
                                  DataColumn(label: Text('Puesto', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                      DataCell(Text(emp.puesto)),
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

  Widget _buildLegendItem(String label, int cantidad, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
        ),
        Text(
          '$cantidad',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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

// Pintor del Gráfico Circular de Torta (Pie Chart)
class _PieChartPainter extends CustomPainter {
  final List<double> valores;
  final List<Color> colores;

  _PieChartPainter({required this.valores, required this.colores});

  @override
  void paint(Canvas canvas, Size size) {
    final total = valores.fold<double>(0.0, (acc, v) => acc + v);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    if (total == 0) {
      final paintVacio = Paint()..color = const Color(0xFFE2E8F0);
      canvas.drawCircle(center, radius, paintVacio);
      return;
    }

    double startAngle = -math.pi / 2;
    for (int i = 0; i < valores.length; i++) {
      final sweepAngle = (valores[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colores[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Efecto Donut opcional interno (centro blanco limpio)
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.45, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => true;
}