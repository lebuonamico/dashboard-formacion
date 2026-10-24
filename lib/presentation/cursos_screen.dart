import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/shared/tipo_curso_chip.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CursosScreen extends ConsumerWidget {
  const CursosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursosAsync = ref.watch(cursosConInstructorProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Catálogo de cursos y formaciones'),

          // Contenido
          Expanded(
            child: Padding(
              padding: paddingPantalla,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterBar(ref),
                  const SizedBox(height: 20),
                  Expanded(
                    child: cursosAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                      data: (cursosList) => FadeIn(
                        child: (() {
                          if (cursosList.isEmpty) {
                            final hayCursos =
                                ref.watch(cursosProvider).value?.isNotEmpty ??
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
                        })(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildFilterBar(WidgetRef ref) {
  final busqueda = ref.watch(busquedaCursoProvider);
  final tipoSeleccionado = ref.watch(filtroTipoCursoProvider);
  final anio = ref.watch(filtroAnioCursosProvider);
  final mes = ref.watch(filtroMesCursosProvider);
  final anios = ref.watch(aniosCursosDisponiblesProvider).value ?? <int>[];

  final aniosOrdenados = <int>{
    ...anios,
    if (anio != null) anio,
  }.toList()..sort((a, b) => b.compareTo(a));

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilterBar(
        scope: 'cursos',
        hasActiveFilters:
            busqueda.isNotEmpty ||
            tipoSeleccionado != null ||
            anio != null ||
            mes != null,
        onClear: () {
          ref.read(busquedaCursoProvider.notifier).state = '';
          ref.read(filtroTipoCursoProvider.notifier).state = null;
          ref.read(filtroAnioCursosProvider.notifier).state = null;
          ref.read(filtroMesCursosProvider.notifier).state = null;
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              key: ValueKey('cursos-anio-$anio'),
              initialValue: anio,
              decoration: const InputDecoration(
                labelText: 'Año (métricas)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todos los años'),
                ),
                for (final a in aniosOrdenados)
                  DropdownMenuItem<int?>(
                    value: a,
                    child: Text('$a'),
                  ),
              ],
              onChanged: (value) {
                ref.read(filtroAnioCursosProvider.notifier).state = value;
                if (value == null) {
                  ref.read(filtroMesCursosProvider.notifier).state = null;
                }
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              key: ValueKey('cursos-mes-$anio-$mes'),
              initialValue: anio == null ? null : mes,
              decoration: const InputDecoration(
                labelText: 'Mes (métricas)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todos los meses'),
                ),
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem<int?>(
                    value: m,
                    child: Text(nombreMes(m)),
                  ),
              ],
              onChanged: anio == null
                  ? null
                  : (value) {
                      ref.read(filtroMesCursosProvider.notifier).state = value;
                    },
            ),
          ),
        ],
      ),
    ],
  );
}

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
    final cs = context.colorScheme;
    // Encabezados, divisores y márgenes salen del dataTableTheme.
    return DataTable(
      columnSpacing: 24,
      // Filas más compactas: entran más cursos sin que se vea apretado.
      headingRowHeight: _altoEncabezado,
      dataRowMinHeight: _altoFila,
      dataRowMaxHeight: _altoFila,
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Nombre del curso')),
        DataColumn(label: Text('Tipo')),
        DataColumn(label: Text('Carga horaria')),
        DataColumn(
          numeric: true,
          label: Text('Personas'),
          tooltip:
              'Colaboradores distintos que cargaron horas en el CRM '
              '(en los cursos de dictado, quienes lo dictaron)',
        ),
        DataColumn(
          numeric: true,
          label: Text('Horas CRM'),
          tooltip: 'Horas cargadas en el CRM para el curso',
        ),
        DataColumn(
          numeric: true,
          label: Text('Promedio por persona'),
          tooltip: 'Horas CRM / personas. Comparalo con la carga horaria',
        ),
        DataColumn(
          numeric: true,
          label: Text('Finalizaron (LMS)'),
          tooltip: 'Colaboradores distintos con la finalización en el LMS',
        ),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              DataCell(
                Text(
                  vm.curso.nombre,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              DataCell(
                vm.curso.tipoLms == null
                    ? const Text('-')
                    : TipoCursoChip(tipo: vm.curso.tipoLms!),
              ),
              DataCell(
                Text(
                  '${vm.curso.cargaHorariaHs.toStringAsFixed(0)} hs',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              DataCell(_celdaMetrica('${vm.personas}', vm.personas == 0)),
              DataCell(
                _celdaMetrica(
                  '${_formatoHoras(vm.horasCrm)} hs',
                  vm.personas == 0,
                ),
              ),
              DataCell(
                _celdaMetrica(
                  vm.promedioHorasPorPersona == null
                      ? '—'
                      : '${_formatoHoras(vm.promedioHorasPorPersona!)} hs',
                  vm.promedioHorasPorPersona == null,
                ),
              ),
              DataCell(_celdaMetrica('${vm.finalizaron}', vm.finalizaron == 0)),
            ],
          ),
      ],
    );
  }

  /// Los ceros van en gris: así se ve de un vistazo qué cursos no tomó nadie.
  Widget _celdaMetrica(String texto, bool vacia) {
    final cs = context.colorScheme;
    return Text(
      texto,
      style: TextStyle(
        fontSize: 13,
        fontWeight: vacia ? FontWeight.w400 : FontWeight.w600,
        color: vacia ? cs.onSurfaceVariant : cs.onSurface,
      ),
    );
  }

  /// Sin decimales si son horas enteras, con uno si no.
  static String _formatoHoras(double horas) => horas == horas.roundToDouble()
      ? horas.toStringAsFixed(0)
      : horas.toStringAsFixed(1);
}
