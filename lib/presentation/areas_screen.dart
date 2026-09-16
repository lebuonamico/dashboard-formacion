import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';

class AreasScreen extends ConsumerWidget {
  const AreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(equiposResumenProvider);

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
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Áreas y Equipos Generales',
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
                        // Barra de búsqueda
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            onChanged: (val) =>
                                ref.read(busquedaEquipoProvider.notifier).state = val,
                            decoration: const InputDecoration(
                              hintText: 'Buscar área o equipo general...',
                              prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Grid de Áreas
                        Expanded(
                          child: areasAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, _) => Center(child: Text('Error: $err')),
                            data: (areas) {
                              if (areas.isEmpty) {
                                return const Center(child: Text('No se encontraron áreas.'));
                              }

                              return GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 180,
                                ),
                                itemCount: areas.length,
                                itemBuilder: (context, index) {
                                  final area = areas[index];
                                  return _buildAreaCard(context, area);
                                },
                              );
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

  Widget _buildAreaCard(BuildContext context, ResumenEquipoViewModel eq) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/areas/${Uri.encodeComponent(eq.nombreArea)}'),
      child: Container(
        padding: const EdgeInsets.all(20),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    eq.nombreArea,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: eq.semaforo.colorFondo,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    eq.semaforo.label,
                    style: TextStyle(color: eq.semaforo.colorTexto, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (eq.equiposGenerales.isNotEmpty)
              Text(
                '${eq.equiposGenerales.length} equipo${eq.equiposGenerales.length == 1 ? '' : 's'} general${eq.equiposGenerales.length == 1 ? '' : 'es'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              )
            else
              const Text('Sin equipo general asignado', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${eq.integrantesCumplen} de ${eq.cantidadIntegrantes} colaboradores en objetivo',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${eq.horasTotalesRealizadas.toStringAsFixed(0)} / ${eq.horasTotalesRequeridas.toStringAsFixed(0)} hs',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${eq.porcentajeCumplimiento.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: eq.semaforo.colorTexto),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (eq.porcentajeCumplimiento / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: eq.semaforo.colorTexto,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'Ver área',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D53C3)),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: Color(0xFF0D53C3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}