import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

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
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF0F172A),
                        ),
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                    data: (detalle) {
                      if (detalle == null) {
                        return const Center(
                          child: Text('Empleado no encontrado.'),
                        );
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
                          _buildTablaCursadas(
                            detalle.historialCursadas,
                            detalle.cursosFinalizados,
                          ),
                          const SizedBox(height: 24),

                          // Cursos Dictados (si aplica al seniority)
                          if (cump.horasRequeridas[TipoCurso
                                      .dictadoCapacitaciones]! >
                                  0 ||
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

  Widget _buildHeaderEmpleado(Empleado emp, CumplimientoEmpleado cump) {
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
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        emp.seniority.label,
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Área de ${emp.area} · Legajo: ${emp.legajo}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emp.mail,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DatoEmpleado(
                      label: 'Equipo',
                      value: _mostrarDato(emp.equipo),
                    ),
                    _DatoEmpleado(
                      label: 'Gerente',
                      value: _mostrarDato(emp.gerente),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Estado de Cumplimiento Global
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cump.cumpleObjetivo
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${cump.totalHorasValidas.toStringAsFixed(0)} / ${cump.totalHorasRequeridas.toStringAsFixed(0)} hs LMS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cump.cumpleObjetivo
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cump.cumpleObjetivo ? 'Objetivo Cumplido' : 'En Progreso',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cump.cumpleObjetivo
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CRM declaró ${cump.totalHorasDeclaradas.toStringAsFixed(0)} hs',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mostrarDato(String valor) => valor.trim().isEmpty ? '-' : valor;

  Widget _buildGridCategorias(CumplimientoEmpleado cump) {
    return Row(
      children: TipoCurso.values.map((tipo) {
        final completadas = cump.horasValidas[tipo] ?? 0.0;
        final declaradas = cump.horasDeclaradas[tipo] ?? 0.0;
        final requeridas = cump.horasRequeridas[tipo] ?? 0.0;
        final requerida = requeridas > 0;
        final cumple = requerida && completadas >= requeridas;

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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  requerida
                      ? '${completadas.toStringAsFixed(0)} / ${requeridas.toStringAsFixed(0)} hs LMS'
                      : 'No requerida',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: !requerida
                        ? const Color(0xFF64748B)
                        : cumple
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CRM declaró ${declaradas.toStringAsFixed(0)} hs',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: requeridas == 0
                        ? 0.0
                        : (completadas / requeridas).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: !requerida
                        ? const Color(0xFFE2E8F0)
                        : cumple
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTablaCursadas(
    List<CursadaViewModel> cursadas,
    Set<String> cursosFinalizados,
  ) {
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

    final grupos = <String, List<CursadaViewModel>>{};
    for (final cursada in cursadas) {
      final cursoId = cursada.curso?.id.trim() ?? '';
      final nombreCurso = cursada.curso?.nombre ?? cursada.cursada.cursoNombre;
      final clave = cursoId.isNotEmpty
          ? 'id:$cursoId'
          : 'nombre:${nombreCurso.trim().toLowerCase()}';
      grupos.putIfAbsent(clave, () => []).add(cursada);
    }

    final cursosAgrupados = grupos.entries.toList()
      ..sort((a, b) => _nombreCurso(a.value).compareTo(_nombreCurso(b.value)));

    return Container(
      child: Column(
        children: cursosAgrupados.map((grupo) {
          final registros = grupo.value
            ..sort((a, b) => b.cursada.fecha.compareTo(a.cursada.fecha));
          final primeraCursada = registros.first;
          final nombreCurso = _nombreCurso(registros);
          final cursoFinalizado = cursosFinalizados.contains(
            CumplimientoService.normalizarNombreCurso(nombreCurso),
          );
          final horasDeclaradas = registros.fold<double>(
            0,
            (total, item) => total + item.cursada.horasTotales,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ExpansionTile(
                key: PageStorageKey<String>('curso-${grupo.key}'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.menu_book_outlined,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombreCurso,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (cursoFinalizado) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Finalizado',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${primeraCursada.curso?.tipo.label ?? 'Tipo sin especificar'} · '
                  '${registros.length} ${registros.length == 1 ? 'registro' : 'registros'} · '
                  '${_formatearHoras(horasDeclaradas)} hs declaradas',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ...registros.map((registro) {
                    final fecha = registro.cursada.fecha;
                    final fechaTexto =
                        '${fecha.day.toString().padLeft(2, '0')}/'
                        '${fecha.month.toString().padLeft(2, '0')}/'
                        '${fecha.year}';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fechaTexto,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          Text(
                            '${_formatearHoras(registro.cursada.horasTotales)} hs',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _nombreCurso(List<CursadaViewModel> cursadas) {
    final primera = cursadas.first;
    return primera.curso?.nombre ?? primera.cursada.cursoNombre;
  }

  String _formatearHoras(double horas) => horas == horas.roundToDouble()
      ? horas.toStringAsFixed(0)
      : horas.toStringAsFixed(1);

  Widget _buildTablaDictados(List<Curso> dictados) {
    if (dictados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No registra cursos dictados como instructor.'),
        ),
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
          DataColumn(
            label: Text(
              'Código',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Curso Impartido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Área Temática',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Horas Sumadas al Plan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: dictados.map((c) {
          return DataRow(
            cells: [
              DataCell(
                Text(c.id, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              DataCell(
                Text(
                  c.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(Text(c.areaCurso)),
              DataCell(
                Text(
                  '${c.cargaHorariaHs.toStringAsFixed(0)} hs',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2410C),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DatoEmpleado extends StatelessWidget {
  final String label;
  final String value;

  const _DatoEmpleado({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
