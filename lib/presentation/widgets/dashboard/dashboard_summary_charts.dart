import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/widgets/shared/donut_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardSummaryCharts extends StatelessWidget {
  final AsyncValue<List<CumplimientoEmpleado>> cumplimientosAsync;

  const DashboardSummaryCharts({super.key, required this.cumplimientosAsync});

  @override
  Widget build(BuildContext context) {
    return cumplimientosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Error: $error'),
      data: (cumplimientos) {
        if (cumplimientos.isEmpty) return const SizedBox.shrink();

        final compliance = _ComplianceSummary.from(cumplimientos);
        final categories = _CategorySummary.from(cumplimientos);

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 850 ? 2 : 1;
            final cardHeight = columns == 2 ? 280.0 : 300.0;

            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: cardHeight,
              ),
              children: [
                _ComplianceChartCard(summary: compliance),
                _CategoryChartCard(summary: categories),
              ],
            );
          },
        );
      },
    );
  }
}

class _ComplianceSummary {
  final int total;
  final int meetsTarget;
  final int attention;
  final int doesNotMeet;

  const _ComplianceSummary({
    required this.total,
    required this.meetsTarget,
    required this.attention,
    required this.doesNotMeet,
  });

  factory _ComplianceSummary.from(List<CumplimientoEmpleado> items) {
    var meetsTarget = 0;
    var attention = 0;
    var doesNotMeet = 0;

    for (final item in items) {
      if (item.porcentajeTotal >= 100) {
        meetsTarget++;
      } else if (item.porcentajeTotal >= 70) {
        attention++;
      } else {
        doesNotMeet++;
      }
    }

    return _ComplianceSummary(
      total: items.length,
      meetsTarget: meetsTarget,
      attention: attention,
      doesNotMeet: doesNotMeet,
    );
  }

  double get meetsPercentage => meetsTarget / total;
}

class _CategorySummary {
  final Map<TipoCurso, double> hours;
  final double averageHours;

  const _CategorySummary({required this.hours, required this.averageHours});

  factory _CategorySummary.from(List<CumplimientoEmpleado> items) {
    final hours = <TipoCurso, double>{};
    for (final tipo in TipoCurso.values) {
      // Sólo lo que suma al objetivo: el total coincide con totalCompleted.
      hours[tipo] = items.fold<double>(
        0,
        (total, item) => total + item.horasAplicablesAlObjetivo(tipo),
      );
    }

    final totalCompleted = items.fold<double>(
      0,
      (total, item) => total + item.totalHorasCompletadas,
    );

    return _CategorySummary(
      hours: hours,
      averageHours: totalCompleted / items.length,
    );
  }

  double get totalHours =>
      hours.values.fold(0, (total, value) => total + value);
}

class _ComplianceChartCard extends StatelessWidget {
  final _ComplianceSummary summary;

  const _ComplianceChartCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final ParColores(texto: verde, fondo: fondoVerde) = context.colores.exito;
    final ParColores(texto: ambar, fondo: fondoAmbar) =
        context.colores.advertencia;
    final ParColores(texto: rojo, fondo: fondoRojo) = context.colores.peligro;
    final legend = [
      _ChartLegendItem(
        label: 'Cumple (>=100%)',
        count: summary.meetsTarget,
        color: verde,
        backgroundColor: fondoVerde,
      ),
      _ChartLegendItem(
        label: 'Atención (70-84%)',
        count: summary.attention,
        color: ambar,
        backgroundColor: fondoAmbar,
      ),
      _ChartLegendItem(
        label: 'No cumple (<70%)',
        count: summary.doesNotMeet,
        color: rojo,
        backgroundColor: fondoRojo,
      ),
    ];

    return _SummaryCard(
      title: 'Estado de cumplimiento',
      subtitle: 'Distribución semáforo de las ${summary.total} personas',
      trailing: 'Meta: 8 h',
      footer: '${summary.meetsTarget} personas alcanzaron el 100% de la meta',
      action: 'Ver nómina',
      onAction: () => context.push('/empleados'),
      child: Row(
        children: [
          DonutChart(
            segments: [
              DonutChartSegment(
                value: summary.meetsTarget.toDouble(),
                color: verde,
              ),
              DonutChartSegment(
                value: summary.attention.toDouble(),
                color: ambar,
              ),
              DonutChartSegment(
                value: summary.doesNotMeet.toDouble(),
                color: rojo,
              ),
            ],
            centerText:
                '${(summary.meetsPercentage * 100).toStringAsFixed(0)}%',
            centerSubtitle: 'EN META',
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _LegendList(items: legend, total: summary.total.toDouble()),
          ),
        ],
      ),
    );
  }
}

class _CategoryChartCard extends StatelessWidget {
  final _CategorySummary summary;

  const _CategoryChartCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    // Mismo color por categoría que los chips de tipo de curso.
    final colors = [
      for (final tipo in TipoCurso.values)
        context.colores.categoria(tipo).texto,
    ];
    final labels = ['Negocio', 'Blandas', 'Libres', 'Dictado'];
    final legend = <_ChartLegendItem>[];

    for (var index = 0; index < TipoCurso.values.length; index++) {
      final tipo = TipoCurso.values[index];
      legend.add(
        _ChartLegendItem(
          label: labels[index],
          value: summary.hours[tipo] ?? 0,
          color: colors[index],
          backgroundColor: context.colorScheme.surfaceContainerLow,
        ),
      );
    }

    return _SummaryCard(
      title: 'Distribución por categorías',
      subtitle: 'Uso de las horas promedio registradas',
      trailing: '4 Pilares',
      footer: 'Capacitaciones distribuidas entre los 4 pilares',
      action: 'Ver cursos',
      onAction: () => context.push('/cursos'),
      child: summary.totalHours == 0
          ? const _SinDatosCategorias()
          : Row(
              children: [
                DonutChart(
                  segments: [
                    for (
                      var index = 0;
                      index < TipoCurso.values.length;
                      index++
                    )
                      DonutChartSegment(
                        value: summary.hours[TipoCurso.values[index]] ?? 0,
                        color: colors[index],
                      ),
                  ],
                  centerText: '${summary.averageHours.toStringAsFixed(1)} h',
                  centerSubtitle: 'PROMEDIO',
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _LegendList(
                    items: legend,
                    total: summary.totalHours,
                    showPercentages: true,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SinDatosCategorias extends StatelessWidget {
  const _SinDatosCategorias();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.donut_large_outlined,
            size: 30,
            color: context.colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 8),
          Text(
            'No se encontraron datos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'No hay horas válidas en ninguna categoría para este período.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Widget child;
  final String footer;
  final String action;
  final VoidCallback onAction;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.child,
    required this.footer,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: context.panel(sombra: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
          Divider(height: 16, color: context.colorScheme.outlineVariant),
          Row(
            children: [
              Expanded(
                child: Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(
                  Icons.arrow_forward,
                  size: 13,
                  color: context.colorScheme.primary,
                ),
                label: Text(action),
                style: TextButton.styleFrom(
                  foregroundColor: context.colorScheme.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegendItem {
  final String label;
  final int? count;
  final double? value;
  final Color color;
  final Color backgroundColor;

  const _ChartLegendItem({
    required this.label,
    this.count,
    this.value,
    required this.color,
    required this.backgroundColor,
  });
}

class _LegendList extends StatelessWidget {
  final List<_ChartLegendItem> items;
  final double total;
  final bool showPercentages;

  const _LegendList({
    required this.items,
    required this.total,
    this.showPercentages = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final item in items) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: item.backgroundColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colores.textoIntermedio,
                    ),
                  ),
                ),
                Text(
                  showPercentages
                      ? '${item.value!.toStringAsFixed(1)} h (${((item.value! / total) * 100).toStringAsFixed(0)}%)'
                      : '${item.count} (${((item.count! / total) * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.colores.textoIntermedio,
                  ),
                ),
              ],
            ),
          ),
          if (item != items.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}
