import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';

class CertificacionScreen extends ConsumerWidget {
  const CertificacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificacionesAsync = ref.watch(certificacionesMoodleProvider);
    final busqueda = ref.watch(busquedaCertificacionMoodleProvider);

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
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Certificaciones LMS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 480,
                          child: TextField(
                            onChanged: (value) =>
                                ref
                                        .read(
                                          busquedaCertificacionMoodleProvider
                                              .notifier,
                                        )
                                        .state =
                                    value,
                            decoration: const InputDecoration(
                              hintText: 'Buscar por legajo o curso',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: certificacionesAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, _) => Center(
                              child: Text(
                                'No se pudieron cargar las certificaciones LMS: $error',
                              ),
                            ),
                            data: (items) {
                              final query = busqueda.trim().toLowerCase();
                              final filtradas = items.where((item) {
                                return item.legajo.toLowerCase().contains(
                                      query,
                                    ) ||
                                    item.cursoNombre.toLowerCase().contains(
                                      query,
                                    );
                              }).toList();
                              if (filtradas.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No hay certificaciones LMS para mostrar.',
                                  ),
                                );
                              }
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.separated(
                                  itemCount: filtradas.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = filtradas[index];
                                    final estadoColor = item.finalizoCurso
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309);
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.menu_book_outlined,
                                        color: Color(0xFF0D53C3),
                                      ),
                                      title: Text(
                                        item.cursoNombre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        item.fechaFinalizacion == null
                                            ? 'Legajo: ${item.legajo} · Sin fecha de finalización'
                                            : 'Legajo: ${item.legajo} · Fecha: ${_formatFecha(item.fechaFinalizacion!)}',
                                      ),
                                      trailing: Text(
                                        item.finalizoCurso
                                            ? 'Finalizado'
                                            : 'Pendiente',
                                        style: TextStyle(
                                          color: estadoColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
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

  String _formatFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}
