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
      hours[tipo] = items.fold<double>(
        0,
        (total, item) => total + (item.horasCompletadas[tipo] ?? 0),
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
    final legend = [
      _ChartLegendItem(
        label: 'Cumple (>=100%)',
        count: summary.meetsTarget,
        color: const Color(0xFF009B61),
        backgroundColor: const Color(0xFFECFDF5),
      ),
      _ChartLegendItem(
        label: 'Atención (70-84%)',
        count: summary.attention,
        color: const Color(0xFFF59E0B),
        backgroundColor: const Color(0xFFFFFBEB),
      ),
      _ChartLegendItem(
        label: 'No cumple (<70%)',
        count: summary.doesNotMeet,
        color: const Color(0xFFF43F5E),
        backgroundColor: const Color(0xFFFFF1F2),
      ),
    ];

    return _SummaryCard(
      title: 'Estado de Cumplimiento',
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
                color: const Color(0xFF009B61),
              ),
              DonutChartSegment(
                value: summary.attention.toDouble(),
                color: const Color(0xFFF59E0B),
              ),
              DonutChartSegment(
                value: summary.doesNotMeet.toDouble(),
                color: const Color(0xFFF43F5E),
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
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF009B61),
      Color(0xFF4F46E5),
      Color(0xFFF59E0B),
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
          backgroundColor: const Color(0xFFF8FAFC),
        ),
      );
    }

    return _SummaryCard(
      title: 'Distribución por Categorías',
      subtitle: 'Uso de las horas promedio registradas',
      trailing: '4 Pilares',
      footer: 'Capacitaciones distribuidas entre los 4 pilares',
      action: 'Ver cursos',
      onAction: () => context.push('/cursos'),
      child: Row(
        children: [
          DonutChart(
            segments: [
              for (var index = 0; index < TipoCurso.values.length; index++)
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailing,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              Expanded(
                child: Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(
                  Icons.arrow_forward,
                  size: 13,
                  color: Color(0xFF2563EB),
                ),
                label: Text(action),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
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
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                Text(
                  showPercentages
                      ? '${item.value!.toStringAsFixed(1)} h (${((item.value! / total) * 100).toStringAsFixed(0)}%)'
                      : '${item.count} (${((item.count! / total) * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
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
