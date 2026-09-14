import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class EmpleadoDetalleScreen extends ConsumerWidget {
  final String legajo;

  const EmpleadoDetalleScreen({super.key, required this.legajo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(detalleEmpleadoProvider(legajo));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                // TopBar con botón Volver
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
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Perfil del Colaborador',
                        style: TextStyle(
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
                      if (detalle == null) {
                        return const Center(child: Text('Empleado no encontrado.'));
                      }

                      final emp = detalle.empleado;
                      final cump = detalle.cumplimiento;

                      return ListView(
                        padding: const EdgeInsets.all(24.0),
                        children: [
                          // Cabecera con datos del empleado
                          _buildHeaderEmpleado(emp, cump),
                          const SizedBox(height: 24),

                          // Desglose de cumplimiento por categoría
                          const Text(
                            'Desglose del Plan de Formación (Q3)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildGridCategorias(cump),
                          const SizedBox(height: 24),

                          // Historial de Cursos Tomados
                          const Text(
                            'Cursos Tomados (Asistencias)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTablaCursadas(detalle.historialCursadas),
                          const SizedBox(height: 24),

                          // Cursos Dictados (si aplica al seniority)
                          if (cump.horasRequeridas[TipoCurso.dictadoCapacitaciones]! > 0 ||
                              detalle.cursosDictados.isNotEmpty) ...[
                            const Text(
                              'Cursos Dictados como Instructor',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTablaDictados(detalle.cursosDictados),
                          ],
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

  Widget _buildHeaderEmpleado(emp, cump) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF0D53C3),
            child: Text(
              emp.nombre.substring(0, 1),
              style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${emp.nombre} ${emp.apellido}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        emp.seniority.label,
                        style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${emp.puesto} · Área de ${emp.area} · Legajo: ${emp.legajo}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  emp.mail,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
              ],
            ),
          ),
          // Estado de Cumplimiento Global
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cump.cumpleObjetivo ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${cump.totalHorasCompletadas.toStringAsFixed(0)} / ${cump.totalHorasRequeridas.toStringAsFixed(0)} hs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cump.cumpleObjetivo ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cump.cumpleObjetivo ? 'Objetivo Cumplido' : 'En Progreso',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cump.cumpleObjetivo ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCategorias(cump) {
    return Row(
      children: TipoCurso.values.map((tipo) {
        final completadas = cump.horasCompletadas[tipo] ?? 0.0;
        final requeridas = cump.horasRequeridas[tipo] ?? 0.0;
        final cumple = completadas >= requeridas;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo.label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${completadas.toStringAsFixed(0)} / ${requeridas.toStringAsFixed(0)} hs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cumple ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: requeridas == 0 ? 1.0 : (completadas / requeridas).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: cumple ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTablaCursadas(List<CursadaViewModel> cursadas) {
    if (cursadas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('No registra cursadas en el período.')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [
          DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Curso', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Horas Computadas', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: cursadas.map((c) {
          final fecha =
              '${c.cursada.fecha.day.toString().padLeft(2, '0')}/${c.cursada.fecha.month.toString().padLeft(2, '0')}/${c.cursada.fecha.year}';
          return DataRow(cells: [
            DataCell(Text(fecha)),
            DataCell(Text(c.curso?.nombre ?? c.cursada.cursoId, style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(Text(c.curso?.tipo.label ?? '-')),
            DataCell(Text('${c.curso?.cargaHorariaHs.toStringAsFixed(0) ?? 0} hs', style: const TextStyle(fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildTablaDictados(List dictados) {
    if (dictados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('No registra cursos dictados como instructor.')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [
          DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Curso Impartido', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Área Temática', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Horas Sumadas al Plan', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: dictados.map((c) {
          return DataRow(cells: [
            DataCell(Text(c.id, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(Text(c.areaCurso)),
            DataCell(Text('${c.cargaHorariaHs.toStringAsFixed(0)} hs', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2410C)))),
          ]);
        }).toList(),
      ),
    );
  }
}