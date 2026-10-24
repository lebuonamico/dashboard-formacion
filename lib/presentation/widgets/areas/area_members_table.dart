import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
import 'package:app_finnegans/presentation/utils/orden_miembros.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_dropdown.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/widgets/shared/category_hours_progress.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/shared/seniority_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Integrantes del área, paginados y con selector para filtrar por avance.
class AreaMiembrosTable extends StatefulWidget {
  final List<CumplimientoEmpleado> miembros;

  /// `cumplido`, `riesgo`, `critico`; vacío = todos.
  final Set<String> filtro;
  final ValueChanged<Set<String>> onFiltro;

  const AreaMiembrosTable({
    super.key,
    required this.miembros,
    required this.filtro,
    required this.onFiltro,
  });

  @override
  State<AreaMiembrosTable> createState() => _AreaMiembrosTableState();
}

class _AreaMiembrosTableState extends State<AreaMiembrosTable> {
  static const _integrantesPorPagina = 8;
  int _paginaActual = 0;
  var _orden = const EstadoOrdenMiembros();

  /// Columnas en el orden en que se muestran; null = no ordenable.
  static const _columnas = <(String, OrdenMiembros?)>[
    ('Legajo', OrdenMiembros.legajo),
    ('Colaborador', OrdenMiembros.colaborador),
    ('Equipo', OrdenMiembros.equipo),
    ('Seniority', OrdenMiembros.seniority),
    ('Horas realizadas / objetivo', OrdenMiembros.horas),
    ('Cumplimiento', OrdenMiembros.cumplimiento),
    ('Por categoría', null),
  ];

  @override
  void didUpdateWidget(covariant AreaMiembrosTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.miembros != widget.miembros ||
        oldWidget.filtro != widget.filtro) {
      _paginaActual = 0;
    }
  }

  /// Mismos cortes que el semáforo, sobre el porcentaje de cada integrante.
  String _estadoMiembro(CumplimientoEmpleado miembro) =>
      miembro.porcentajeTotal >= 100.0
      ? 'cumplido'
      : miembro.porcentajeTotal >= 70.0
      ? 'riesgo'
      : 'critico';

  List<CumplimientoEmpleado> get _miembrosFiltrados => widget.miembros
      .where(
        (miembro) =>
            widget.filtro.isEmpty ||
            widget.filtro.contains(_estadoMiembro(miembro)),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final estadoOptions = cascadeFilterOptions(
      [
        for (final miembro in widget.miembros)
          {'Estado': _estadoMiembro(miembro)},
      ],
      {'Estado': widget.filtro},
    )['Estado'];
    const etiquetasEstado = {
      'cumplido': 'Cumplidos',
      'riesgo': 'En riesgo',
      'critico': 'Críticos',
    };
    final visiblesFiltrados = _orden.aplicar(_miembrosFiltrados);
    final indiceOrden = _columnas.indexWhere(
      (columna) => columna.$2 != null && columna.$2 == _orden.columna,
    );
    final totalIntegrantes = visiblesFiltrados.length;
    final totalPaginas = totalIntegrantes == 0
        ? 1
        : (totalIntegrantes + _integrantesPorPagina - 1) ~/
              _integrantesPorPagina;
    final paginaSegura = _paginaActual.clamp(0, totalPaginas - 1);
    final inicio = paginaSegura * _integrantesPorPagina;
    final finCalculado = inicio + _integrantesPorPagina;
    final fin = finCalculado > totalIntegrantes
        ? totalIntegrantes
        : finCalculado;
    final miembrosVisibles = visiblesFiltrados.sublist(inicio, fin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          spacing: 16,
          children: [
            Text(
              'Integrantes ($totalIntegrantes)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            SizedBox(
              width: 250,
              child: FilterDropdown<String>.multiple(
                selectedValues: widget.filtro,
                incompatibleValues:
                    estadoOptions?.incompatibleValues ?? const {},
                hint: 'Estado',
                icon: Icons.traffic_outlined,
                items: [
                  for (final value in estadoOptions?.values ?? <String>[])
                    DropdownMenuItem(
                      value: value,
                      child: Text(etiquetasEstado[value] ?? value),
                    ),
                ],
                onSelectionChanged: widget.onFiltro,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (miembrosVisibles.isEmpty)
          const EmptyDataState(
            compact: true,
            icon: Icons.filter_alt_off_outlined,
            title: 'Ningún integrante coincide con el filtro.',
          )
        else ...[
          if (totalPaginas > 1) ...[
            PaginacionResultados(
              paginaActual: paginaSegura,
              cantidadPaginas: totalPaginas,
              desde: inicio + 1,
              hasta: fin,
              totalResultados: totalIntegrantes,
              etiquetaResultados: 'integrantes',
              icono: Icons.people_outline,
              onPrevious: paginaSegura > 0
                  ? () => setState(() => _paginaActual = paginaSegura - 1)
                  : null,
              onNext: paginaSegura < totalPaginas - 1
                  ? () => setState(() => _paginaActual = paginaSegura + 1)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            decoration: context.panel(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < 1100
                          ? 1100
                          : constraints.maxWidth,
                    ),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStatePropertyAll(
                        context.colorScheme.surfaceContainerLow,
                      ),
                      sortColumnIndex: indiceOrden < 0 ? null : indiceOrden,
                      sortAscending: _orden.ascendente,
                      columns: [
                        for (final (titulo, orden) in _columnas)
                          DataColumn(
                            label: Text(titulo),
                            onSort: orden == null
                                ? null
                                : (_, _) => setState(() {
                                    _orden = _orden.alternar(orden);
                                    _paginaActual = 0;
                                  }),
                          ),
                      ],
                      rows: miembrosVisibles.map(_buildRow).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  DataRow _buildRow(CumplimientoEmpleado miembro) {
    final empleado = miembro.empleado;
    final cumple = miembro.cumpleObjetivo;
    final equipo = empleado.equipo.trim();

    return DataRow(
      onSelectChanged: (_) =>
          context.push('/empleados/${Uri.encodeComponent(empleado.legajo)}'),
      cells: [
        DataCell(Text(empleado.legajo)),
        DataCell(
          Text(
            empleado.nombreCompleto,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Text(
            equipo.isEmpty ? 'Sin equipo asignado' : equipo,
            style: TextStyle(
              color: equipo.isEmpty
                  ? context.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        ),
        DataCell(SeniorityChip(seniority: empleado.seniority)),
        DataCell(
          Text(
            '${miembro.totalHorasCompletadas.toStringAsFixed(1)} / ${miembro.totalHorasRequeridas.toStringAsFixed(1)} h',
          ),
        ),
        DataCell(
          Text(
            formatearPorcentaje(miembro.porcentajeTotal),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cumple
                  ? context.colores.exito.texto
                  : context.colores.advertencia.texto,
            ),
          ),
        ),
        DataCell(
          ProgresoHorasPorCategoria(
            cumplimiento: miembro,
            mostrarSoloHorasAplicables: true,
          ),
        ),
      ],
    );
  }
}
