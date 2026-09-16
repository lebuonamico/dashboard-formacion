import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';

class EquipoScreen extends ConsumerWidget {
  final String area;
  final String equipo;

  const EquipoScreen({super.key, required this.area, required this.equipo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(
      detalleEquipoGeneralProvider((area: area, equipo: equipo)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
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
                      Expanded(
                        child: Text(
                          'Equipo General: $equipo',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: detalleAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Error: $error')),
                    data: (detalle) => ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text('Área: ${detalle.nombreArea}', style: const TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        _buildMembersCard(context, detalle.miembros),
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

  Widget _buildMembersCard(BuildContext context, List miembros) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [
          DataColumn(label: Text('Legajo', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Colaborador', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Área', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Seniority', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Cumplimiento', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: miembros.map((miembro) {
          final empleado = miembro.empleado;
          return DataRow(
            onSelectChanged: (_) => context.push('/empleados/${empleado.legajo}'),
            cells: [
              DataCell(Text(empleado.legajo)),
              DataCell(Text(empleado.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(empleado.area)),
              DataCell(Text(empleado.seniority.label)),
              DataCell(Text('${miembro.porcentajeTotal.toStringAsFixed(0)}%')),
            ],
          );
        }).toList(),
      ),
    );
  }
}