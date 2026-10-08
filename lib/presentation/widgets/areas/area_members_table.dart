import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/category_hours_progress.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/shared/seniority_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Integrantes del área, paginados y con chips para filtrar por avance.
class AreaMiembrosTable extends StatefulWidget {
  final List<CumplimientoEmpleado> miembros;

  /// `cumplido`, `riesgo`, `critico` o null (todos).
  final String? filtro;
  final ValueChanged<String?> onFiltro;

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

  @override
  void didUpdateWidget(covariant AreaMiembrosTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.miembros != widget.miembros ||
        oldWidget.filtro != widget.filtro) {
      _paginaActual = 0;
    }
  }

  /// Mismos cortes que el semáforo, sobre el porcentaje de cada integrante.
  List<CumplimientoEmpleado> get _miembrosFiltrados {
    return widget.miembros.where((miembro) {
      final porcentaje = miembro.porcentajeTotal;
      switch (widget.filtro) {
        case 'cumplido':
          return porcentaje >= 100.0;
        case 'riesgo':
          return porcentaje >= 70.0 && porcentaje < 100.0;
        case 'critico':
          return porcentaje < 70.0;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visiblesFiltrados = _miembrosFiltrados;
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: areasInk,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FiltroChip(
                  label: 'Todos',
                  seleccionado: widget.filtro == null,
                  onTap: () => widget.onFiltro(null),
                ),
                const SizedBox(width: 8),
                _FiltroChip(
                  label: 'Cumplidos',
                  seleccionado: widget.filtro == 'cumplido',
                  onTap: () => widget.onFiltro('cumplido'),
                ),
                const SizedBox(width: 8),
                _FiltroChip(
                  label: 'En riesgo',
                  seleccionado: widget.filtro == 'riesgo',
                  onTap: () => widget.onFiltro('riesgo'),
                ),
                const SizedBox(width: 8),
                _FiltroChip(
                  label: 'Críticos',
                  seleccionado: widget.filtro == 'critico',
                  onTap: () => widget.onFiltro('critico'),
                ),
              ],
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
            decoration: areasPanelDecoration(),
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
                      headingRowColor: const WidgetStatePropertyAll(
                        areasBackground,
                      ),
                      columns: const [
                        DataColumn(label: Text('Legajo')),
                        DataColumn(label: Text('Colaborador')),
                        DataColumn(label: Text('Equipo')),
                        DataColumn(label: Text('Seniority')),
                        DataColumn(label: Text('Horas realizadas / objetivo')),
                        DataColumn(label: Text('Cumplimiento')),
                        DataColumn(label: Text('Por categoría')),
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
            style: TextStyle(color: equipo.isEmpty ? areasMuted : null),
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
            '${miembro.porcentajeTotal.toStringAsFixed(0)}%',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cumple ? const Color(0xFF15803D) : const Color(0xFFB45309),
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

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? areasBrand : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado ? areasBrand : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: seleccionado ? Colors.white : areasMuted,
          ),
        ),
      ),
    );
  }
}
