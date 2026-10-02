import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_category_distribution.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:app_finnegans/presentation/widgets/equipos/estado_equipo_style.dart';
import 'package:app_finnegans/presentation/widgets/shared/paginacion_resultados.dart';
import 'package:app_finnegans/presentation/widgets/shared/progreso_horas_por_categoria.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Leandro: Detalle del equipo seleccionado en el dashboard de Equipos.
class EquipoScreen extends ConsumerWidget {
  final String area;
  final String equipo;

  const EquipoScreen({super.key, required this.area, required this.equipo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(
      detalleEquipoGeneralProvider((area: area, equipo: equipo)),
    );
    final alcance = ref.watch(alcancePeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final soloRegistros = ref.watch(soloRegistrosCargadosPeriodoProvider);
    final periodo = _periodoLabel(alcance, mes, anio, soloRegistros);

    return Scaffold(
      backgroundColor: equiposBackground,
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                _TopBar(onBack: () => context.pop()),
                Expanded(
                  child: detalleAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: equiposBrand),
                    ),
                    error: (error, _) => _ErrorState(message: '$error'),
                    data: (detalle) =>
                        _EquipoContent(detalle: detalle, periodo: periodo),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _periodoLabel(
    AlcancePeriodo alcance,
    int mes,
    int anio,
    bool soloRegistros,
  ) {
    if (alcance == AlcancePeriodo.mensual) {
      return '${_nombreMes(mes)} $anio';
    }
    return soloRegistros ? 'Año $anio · sólo meses con registros' : 'Año $anio';
  }

  String _nombreMes(int mes) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return meses[mes - 1];
  }
}

class _EquipoContent extends StatelessWidget {
  final DetalleEquipoGeneralViewModel detalle;
  final String periodo;

  const _EquipoContent({required this.detalle, required this.periodo});

  @override
  Widget build(BuildContext context) {
    final equipo = detalle.resumen;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        _EquipoHeader(equipo: equipo, periodo: periodo),
        const SizedBox(height: 22),
        _KpiGrid(
          items: [
            _KpiData(
              title: 'Integrantes',
              value: '${equipo.cantidadIntegrantes}',
              detail: 'nómina del equipo',
              icon: Icons.people_outline,
              color: equiposBrand,
            ),
            _KpiData(
              title: 'Horas realizadas',
              value: _horas(equipo.horasRealizadas),
              detail: 'aplicadas al objetivo del período',
              icon: Icons.schedule_outlined,
              color: const Color(0xFF0E7490),
            ),
            _KpiData(
              title: 'Objetivo del período',
              value: _horas(equipo.horasObjetivo),
              detail: 'según seniority y período',
              icon: Icons.flag_outlined,
              color: const Color(0xFF6941C6),
            ),
            _KpiData(
              title: 'Cumplimiento',
              value: '${equipo.porcentajeCumplimiento.toStringAsFixed(1)}%',
              detail:
                  '${equipo.integrantesEnObjetivo} de ${equipo.cantidadIntegrantes} en objetivo',
              icon: Icons.trending_up,
              color: equipo.estado.colorTexto,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final distribucion = EquiposCategoryDistribution(
              horasNegocio: equipo.horasNegocio,
              horasBlandas: equipo.horasBlandas,
              horasLibres: equipo.horasLibres,
              horasDictado: equipo.horasDictado,
            );
            final avance = _TeamProgressPanel(equipo: equipo);

            if (constraints.maxWidth < 1050) {
              return Column(
                children: [distribucion, const SizedBox(height: 16), avance],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SizedBox(height: 260, child: distribucion)),
                const SizedBox(width: 16),
                Expanded(child: SizedBox(height: 260, child: avance)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _MembersTable(miembros: detalle.miembros),
      ],
    );
  }

  String _horas(double value) => '${value.toStringAsFixed(1)} h';
}

class _EquipoHeader extends StatelessWidget {
  final EquipoGlobalViewModel equipo;
  final String periodo;

  const _EquipoHeader({required this.equipo, required this.periodo});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              equipo.nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: equiposInk,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${equipo.area} · Líder: ${equipo.lider}',
              style: const TextStyle(fontSize: 14, color: equiposMuted),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: equiposBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: equiposMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    periodo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: equiposInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: equipo.estado.colorFondo,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                equipo.estado.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: equipo.estado.colorTexto,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _KpiGrid extends StatelessWidget {
  final List<_KpiData> items;

  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  height: 112,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: equiposPanelDecoration(withShadow: true),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon, color: item.color, size: 21),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: equiposMuted,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.value,
                                style: const TextStyle(
                                  fontSize: 24,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  color: equiposInk,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: equiposMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _TeamProgressPanel extends StatelessWidget {
  final EquipoGlobalViewModel equipo;

  const _TeamProgressPanel({required this.equipo});

  @override
  Widget build(BuildContext context) {
    final progress = (equipo.porcentajeCumplimiento / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: equiposPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avance del equipo',
            style: TextStyle(fontWeight: FontWeight.w700, color: equiposInk),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${equipo.porcentajeCumplimiento.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: equipo.estado.colorTexto,
                ),
              ),
              Text(
                '${equipo.horasRealizadas.toStringAsFixed(1)} de ${equipo.horasObjetivo.toStringAsFixed(1)} h',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: equiposMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFEAECF0),
              color: equipo.estado.colorTexto,
            ),
          ),
          const SizedBox(height: 20),
          _MetricRow(
            label: 'Integrantes en objetivo',
            value:
                '${equipo.integrantesEnObjetivo} de ${equipo.cantidadIntegrantes}',
          ),
          const Divider(height: 22),
          _MetricRow(
            label: 'Promedio por integrante',
            value: '${equipo.promedioPorColaborador.toStringAsFixed(1)} h',
          ),
          const Divider(height: 22),
          _MetricRow(
            label: 'Desvío de horas',
            value: equipo.desvioHoras >= 0
                ? '+${equipo.desvioHoras.toStringAsFixed(1)} h'
                : '-${equipo.desvioHoras.abs().toStringAsFixed(1)} h',
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: equiposMuted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: equiposInk,
          ),
        ),
      ],
    );
  }
}

class _MembersTable extends StatefulWidget {
  final List<CumplimientoEmpleado> miembros;

  const _MembersTable({required this.miembros});

  @override
  State<_MembersTable> createState() => _MembersTableState();
}

class _MembersTableState extends State<_MembersTable> {
  // Leandro: La tabla limita las filas y cambia de página sin recalcular datos.
  static const _integrantesPorPagina = 3;
  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant _MembersTable oldWidget) {
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
    final inicio = _paginaActual * _integrantesPorPagina;
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
          PaginacionResultados(
            paginaActual: _paginaActual,
            cantidadPaginas: totalPaginas,
            desde: inicio + 1,
            hasta: fin,
            totalResultados: totalIntegrantes,
            etiquetaResultados: 'integrantes',
            icono: Icons.people_outline,
            onPrevious: _paginaActual > 0
                ? () => setState(() => _paginaActual--)
                : null,
            onNext: _paginaActual < totalPaginas - 1
                ? () => setState(() => _paginaActual++)
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
                    rows: miembrosVisibles.map((miembro) {
                      final empleado = miembro.empleado;
                      final cumple = miembro.cumpleObjetivo;
                      return DataRow(
                        onSelectChanged: (_) => context.push(
                          '/empleados/${Uri.encodeComponent(empleado.legajo)}',
                        ),
                        cells: [
                          DataCell(Text(empleado.legajo)),
                          DataCell(
                            Text(
                              empleado.nombreCompleto,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
                                color: cumple
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
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
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: equiposBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Detalle de equipo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: equiposInk,
              ),
            ),
          ),
          const CircleAvatar(
            radius: 18,
            backgroundColor: equiposBrand,
            child: Text('U', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No pudimos cargar el equipo.\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
