import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';

class EmpleadosScreen extends ConsumerWidget {
  const EmpleadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empleadosFiltrados = ref.watch(empleadosFiltradosProvider);

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
                        'Directorio de Empleados',
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
                          child: empleadosFiltrados.when(
                            loading: () =>
                                const Center(child: CircularProgressIndicator()),
                            error: (err, _) =>
                                Center(child: Text('Error: $err')),
                            data: (empleados) {
                              if (empleados.isEmpty) {
                                return const Center(
                                  child: Text('No se encontraron empleados.'),
                                );
                              }
                              return _buildTablaDirectorio(context, empleados);
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
    final senioritySeleccionado = ref.watch(filtroSeniorityProvider);

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
                  ref.read(busquedaEmpleadoProvider.notifier).state = val,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, legajo, puesto o área...',
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
              child: DropdownButton<Seniority?>(
                value: senioritySeleccionado,
                hint: const Text('Todos los seniorities'),
                items: [
                  const DropdownMenuItem<Seniority?>(
                    value: null,
                    child: Text('Todos los seniorities'),
                  ),
                  ...Seniority.values.map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label),
                    ),
                  ),
                ],
                onChanged: (val) =>
                    ref.read(filtroSeniorityProvider.notifier).state = val,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablaDirectorio(BuildContext context, List<Empleado> empleados) {
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
            horizontalMargin: 20,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Legajo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Empleado', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Puesto', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Área', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Seniority', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: empleados.map((emp) {
              return DataRow(
                onSelectChanged: (_) => context.push('/empleados/${emp.legajo}'),
                cells: [
                  DataCell(Text(emp.legajo, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            emp.nombre.substring(0, 1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${emp.nombre} ${emp.apellido}'),
                      ],
                    ),
                  ),
                  DataCell(Text(emp.puesto)),
                  DataCell(Text(emp.area)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        emp.seniority.label,
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(emp.mail, style: const TextStyle(color: Color(0xFF64748B)))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}