import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class CursosScreen extends ConsumerWidget {
  const CursosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursosAsync = ref.watch(cursosConInstructorProvider);

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
                        'Catálogo de Cursos y Formaciones',
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
                        _buildFilterBar(ref),
                        const SizedBox(height: 20),
                        Expanded(
                          child: cursosAsync.when(
                            loading: () =>
                                const Center(child: CircularProgressIndicator()),
                            error: (err, _) =>
                                Center(child: Text('Error: $err')),
                            data: (cursosList) {
                              if (cursosList.isEmpty) {
                                return const Center(
                                  child: Text('No se encontraron cursos con los filtros aplicados.'),
                                );
                              }
                              return _buildTablaCursos(cursosList);
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

  Widget _buildFilterBar(WidgetRef ref) {
    final tipoSeleccionado = ref.watch(filtroTipoCursoProvider);

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
                  ref.read(busquedaCursoProvider.notifier).state = val,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, área o instructor...',
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
              child: DropdownButton<TipoCurso?>(
                value: tipoSeleccionado,
                hint: const Text('Todos los tipos'),
                items: [
                  const DropdownMenuItem<TipoCurso?>(
                    value: null,
                    child: Text('Todos los tipos'),
                  ),
                  ...TipoCurso.values.map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label),
                    ),
                  ),
                ],
                onChanged: (val) =>
                    ref.read(filtroTipoCursoProvider.notifier).state = val,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablaCursos(List<CursoViewModel> cursosList) {
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
              DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Nombre del Curso', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Área Temática', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Instructor', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Carga Horaria', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: cursosList.map((vm) {
              final c = vm.curso;
              return DataRow(
                cells: [
                  DataCell(Text(c.id, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(_buildTipoChip(c.tipo)),
                  DataCell(Text(c.areaCurso)),
                  DataCell(
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(vm.nombreInstructor),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      '${c.cargaHorariaHs.toStringAsFixed(0)} hs',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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

  Widget _buildTipoChip(TipoCurso tipo) {
    Color bg;
    Color text;

    switch (tipo) {
      case TipoCurso.habilidadesDeNegocio:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        break;
      case TipoCurso.habilidadesBlandas:
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF7E22CE);
        break;
      case TipoCurso.libresExploracion:
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        break;
      case TipoCurso.dictadoCapacitaciones:
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFC2410C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tipo.label,
        style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}