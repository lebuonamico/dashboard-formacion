import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';

class CursadasScreen extends ConsumerWidget {
  const CursadasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursadasAsync = ref.watch(cursadasCompletasProvider);
    final cursosAsync = ref.watch(cursosProvider);

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
                        'Registro de Cursadas y Asistencias',
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
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterBar(ref, cursosAsync.value ?? []),
                        const SizedBox(height: 20),
                        Expanded(
                          child: cursadasAsync.when(
                            loading: () =>
                                const Center(child: CircularProgressIndicator()),
                            error: (err, _) =>
                                Center(child: Text('Error: $err')),
                            data: (lista) {
                              if (lista.isEmpty) {
                                return const Center(
                                  child: Text('No hay registros de asistencia coincidentes.'),
                                );
                              }
                              return _buildTablaAsistencias(lista);
                            },
                          ),
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

  Widget _buildFilterBar(WidgetRef ref, List<Curso> cursos) {
    final cursoSeleccionado = ref.watch(filtroCursoIdProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) =>
                  ref.read(busquedaCursadaProvider.notifier).state = val,
              decoration: const InputDecoration(
                hintText: 'Buscar por colaborador, curso o legajo...',
                prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                isDense: true,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<String?>(
                value: cursoSeleccionado,
                hint: const Text('Todos los cursos'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos los cursos'),
                  ),
                  ...cursos.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.nombre),
                    ),
                  ),
                ],
                onChanged: (val) =>
                    ref.read(filtroCursoIdProvider.notifier).state = val,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablaAsistencias(List<CursadaViewModel> lista) {
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
            horizontalMargin: 20,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('ID Registro', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Colaborador Asistente', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Seniority', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Curso Tomado', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Carga Computada', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: lista.map((vm) {
              final csd = vm.cursada;
              final emp = vm.empleado;
              final cur = vm.curso;

              final fechaFormato =
                  '${csd.fecha.day.toString().padLeft(2, '0')}/${csd.fecha.month.toString().padLeft(2, '0')}/${csd.fecha.year}';

              return DataRow(
                cells: [
                  DataCell(Text(csd.id, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(fechaFormato)),
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            emp != null ? emp.nombre.substring(0, 1) : '?',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(emp != null ? '${emp.nombre} ${emp.apellido} (${csd.empleadoLegajo})' : csd.empleadoLegajo),
                      ],
                    ),
                  ),
                  DataCell(Text(emp?.seniority.label ?? '-')),
                  DataCell(Text(cur?.nombre ?? csd.cursoId, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${cur?.cargaHorariaHs.toStringAsFixed(0) ?? 0} hs',
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
    );
  }
}