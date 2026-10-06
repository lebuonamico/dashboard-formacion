import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/widgets/shared/category_hours_progress.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EquipoMiembrosTable extends StatefulWidget {
  final List<CumplimientoEmpleado> miembros;

  const EquipoMiembrosTable({super.key, required this.miembros});

  @override
  State<EquipoMiembrosTable> createState() => _EquipoMiembrosTableState();
}

class _EquipoMiembrosTableState extends State<EquipoMiembrosTable> {
  static const _integrantesPorPagina = 8;
  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant EquipoMiembrosTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.miembros != widget.miembros) {
      _paginaActual = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalIntegrantes = widget.miembros.length;
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
    final miembrosVisibles = widget.miembros.sublist(inicio, fin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Integrantes ($totalIntegrantes)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: equiposInk,
          ),
        ),
        const SizedBox(height: 12),
        if (totalPaginas > 1) ...[
          // Leandro: llama a PaginacionResultados para recorrer las páginas de integrantes.
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
          decoration: equiposPanelDecoration(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth < 980
                        ? 980
                        : constraints.maxWidth,
                  ),
                  child: DataTable(
                    headingRowColor: const WidgetStatePropertyAll(
                      equiposBackground,
                    ),
                    columns: const [
                      DataColumn(label: Text('Legajo')),
                      DataColumn(label: Text('Colaborador')),
                      DataColumn(label: Text('Seniority')),
                      DataColumn(label: Text('Horas realizadas / objetivo')),
                      DataColumn(label: Text('Cumplimiento')),
                      DataColumn(label: Text('Por categoría')),
                    ],
                    // Leandro: llama a _buildRow para convertir cada integrante visible en una fila.
                    rows: miembrosVisibles.map(_buildRow).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(CumplimientoEmpleado miembro) {
    final empleado = miembro.empleado;
    final cumple = miembro.cumpleObjetivo;

    return DataRow(
      // Leandro: llama a context.push para abrir el detalle del colaborador seleccionado.
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
        DataCell(Text(empleado.seniority.label)),
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
          // Leandro: llama a ProgresoHorasPorCategoria para mostrar el avance del integrante por categoría.
          ProgresoHorasPorCategoria(
            cumplimiento: miembro,
            mostrarSoloHorasAplicables: true,
          ),
        ),
      ],
    );
  }
}
