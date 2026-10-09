import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/shared/tipo_curso_chip.dart';
import 'package:app_finnegans/presentation/widgets/shared/user_avatar.dart';
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
                        'Catálogo de cursos y formaciones',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const UserAvatar(),
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
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (err, _) =>
                                Center(child: Text('Error: $err')),
                            data: (cursosList) {
                              if (cursosList.isEmpty) {
                                final hayCursos =
                                    ref
                                        .watch(cursosProvider)
                                        .value
                                        ?.isNotEmpty ??
                                    false;
                                return SingleChildScrollView(
                                  child: hayCursos
                                      ? const EmptyDataState(
                                          icon: Icons.search_off_outlined,
                                          title:
                                              'No se encontraron cursos con los filtros aplicados.',
                                          message:
                                              'Probá con otra búsqueda o tipo de curso.',
                                        )
                                      : const EmptyDataState(
                                          icon: Icons.menu_book_outlined,
                                          title: 'No hay cursos cargados.',
                                          message:
                                              'Importá el catálogo de cursos o sincronizalo desde Moodle.',
                                        ),
                                );
                              }
                              return _TablaCursosPaginada(cursos: cursosList);
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
                hintText: 'Buscar por nombre o ID...',
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
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
                    (t) => DropdownMenuItem(value: t, child: Text(t.label)),
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
}

/// Gris de los datos secundarios (encabezados y columna ID).
const _grisSuave = Color(0xFF64748B);
const _tinta = Color(0xFF0F172A);

/// Encabezados en gris y chicos: el que manda visualmente es el nombre del
/// curso, no el título de la columna.
const _estiloEncabezado = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: _grisSuave,
);

/// Tabla del catálogo, de a una página por vez, para no tener que scrollear.
class _TablaCursosPaginada extends StatefulWidget {
  final List<CursoViewModel> cursos;

  const _TablaCursosPaginada({required this.cursos});

  @override
  State<_TablaCursosPaginada> createState() => _TablaCursosPaginadaState();
}

class _TablaCursosPaginadaState extends State<_TablaCursosPaginada> {
  static const _altoFila = 44.0;
  static const _altoEncabezado = 44.0;
  static const _altoPaginador = 60.0;
  static const _separacion = 12.0;

  /// Mínimo razonable si la ventana queda muy baja.
  static const _minimoPorPagina = 5;

  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant _TablaCursosPaginada oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar el filtro o la búsqueda, volver a la primera página.
    if (oldWidget.cursos != widget.cursos) {
      _paginaActual = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.cursos.length;

        // Cuántas filas entran en el alto que nos dieron. Así la tabla llena la
        // página y no queda un hueco entre la última fila y el paginador.
        final altoParaTabla =
            constraints.maxHeight - _altoPaginador - _separacion;
        final cursosPorPagina = ((altoParaTabla - _altoEncabezado) / _altoFila)
            .floor()
            .clamp(
              _minimoPorPagina,
              // Nunca más filas que cursos hay.
              total < _minimoPorPagina ? _minimoPorPagina : total,
            );

        final totalPaginas = total == 0
            ? 1
            : (total + cursosPorPagina - 1) ~/ cursosPorPagina;
        final paginaSegura = _paginaActual.clamp(0, totalPaginas - 1);
        final inicio = paginaSegura * cursosPorPagina;
        final finCalculado = inicio + cursosPorPagina;
        final fin = finCalculado > total ? total : finCalculado;
        final visibles = widget.cursos.sublist(inicio, fin);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sin recuadro: la tabla se dibuja directo sobre la página y ocupa
            // todo el ancho disponible.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  // Red de seguridad por si algo no entra.
                  child: SingleChildScrollView(child: _tabla(visibles)),
                ),
              ),
            ),
            if (totalPaginas > 1) ...[
              const SizedBox(height: _separacion),
              PaginacionResultados(
                paginaActual: paginaSegura,
                cantidadPaginas: totalPaginas,
                desde: inicio + 1,
                hasta: fin,
                totalResultados: total,
                etiquetaResultados: 'cursos',
                icono: Icons.school_outlined,
                onPrevious: paginaSegura > 0
                    ? () => setState(() => _paginaActual = paginaSegura - 1)
                    : null,
                onNext: paginaSegura < totalPaginas - 1
                    ? () => setState(() => _paginaActual = paginaSegura + 1)
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _tabla(List<CursoViewModel> visibles) {
    return DataTable(
      // Sin fondo propio: el encabezado se apoya sobre el color de la página y
      // se distingue por la negrita y la línea divisoria de abajo.
      headingRowColor: WidgetStateProperty.all(Colors.transparent),
      horizontalMargin: 0,
      columnSpacing: 24,
      // Filas más compactas: entran más cursos sin que se vea apretado.
      headingRowHeight: 44,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 44,
      dividerThickness: 1,
      columns: const [
        DataColumn(label: Text('ID', style: _estiloEncabezado)),
        DataColumn(label: Text('Nombre del curso', style: _estiloEncabezado)),
        DataColumn(label: Text('Tipo', style: _estiloEncabezado)),
        DataColumn(label: Text('Carga horaria', style: _estiloEncabezado)),
      ],
      rows: [
        for (final vm in visibles)
          DataRow(
            cells: [
              // El ID es dato secundario: va en gris para que no le compita al
              // nombre del curso.
              DataCell(
                Text(
                  vm.curso.id,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _grisSuave,
                  ),
                ),
              ),
              DataCell(
                Text(
                  vm.curso.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _tinta,
                  ),
                ),
              ),
              DataCell(TipoCursoChip(tipo: vm.curso.tipo)),
              DataCell(
                Text(
                  '${vm.curso.cargaHorariaHs.toStringAsFixed(0)} hs',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _tinta,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
