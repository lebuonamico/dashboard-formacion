import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/core/widgets/donut_chart.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_colors.dart';

class DashboardSummaryCharts extends StatelessWidget {
  final AsyncValue<DashboardDistribution?> distributionAsync;
  final VoidCallback? onRetry;

  const DashboardSummaryCharts({
    super.key,
    required this.distributionAsync,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return distributionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorDataState(
        title: 'No pudimos cargar esta sección',
        error: error,
        compact: true,
        onRetry: onRetry,
      ),
      data: (distribution) {
        if (distribution == null) {
          return const EmptyDataState(
            compact: true,
            icon: Icons.donut_large_outlined,
            title: 'No hay colaboradores evaluados en este período.',
          );
        }

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
                _ComplianceChartCard(summary: distribution.compliance),
                _CategoryChartCard(summary: distribution.categories),
              ],
            );
          },
        );
      },
    );
  }
}

class _ComplianceChartCard extends StatelessWidget {
  final ComplianceDistribution summary;

  const _ComplianceChartCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final ColorPair(text: green, background: greenBackground) =
        context.colors.success;
    final ColorPair(text: amber, background: amberBackground) =
        context.colors.warning;
    final ColorPair(text: red, background: redBackground) =
        context.colors.danger;
    final legend = [
      _ChartLegendItem(
        label: 'Cumple (>=100%)',
        count: summary.onTarget,
        color: green,
        backgroundColor: greenBackground,
      ),
      _ChartLegendItem(
        label: 'Atención (70-84%)',
        count: summary.atRisk,
        color: amber,
        backgroundColor: amberBackground,
      ),
      _ChartLegendItem(
        label: 'No cumple (<70%)',
        count: summary.critical,
        color: red,
        backgroundColor: redBackground,
      ),
    ];

    return _SummaryCard(
      title: 'Estado de cumplimiento',
      subtitle: 'Distribución semáforo de las ${summary.total} personas',
      trailing: 'Meta según seniority',
      footer: '${summary.onTarget} personas alcanzaron el 100% de la meta',
      action: 'Ver nómina',
      onAction: () => context.go('/empleados'),
      child: Row(
        children: [
          DonutChart(
            segments: [
              DonutChartSegment(
                value: summary.onTarget.toDouble(),
                color: green,
              ),
              DonutChartSegment(value: summary.atRisk.toDouble(), color: amber),
              DonutChartSegment(value: summary.critical.toDouble(), color: red),
            ],
            centerText: '${(summary.onTargetShare * 100).toStringAsFixed(0)}%',
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
  final CategoryDistribution summary;

  const _CategoryChartCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    // Same color per category as the course type chips.
    final legend = CourseCategory.values
        .map(
          (type) => _ChartLegendItem(
            label: type.shortLabel,
            value: summary.hours[type] ?? 0,
            color: context.colors.category(type).text,
            backgroundColor: context.colorScheme.surfaceContainerLow,
          ),
        )
        .toList();

    return _SummaryCard(
      title: 'Distribución por categorías',
      subtitle:
          '${summary.totalHours.toStringAsFixed(0)} de '
          '${summary.totalTarget.toStringAsFixed(0)} h válidas',
      trailing: '4 Pilares',
      footer: 'Capacitaciones distribuidas entre los 4 pilares',
      action: 'Ver cursos',
      onAction: () => context.go('/cursos'),
      child: summary.totalHours == 0
          ? const _NoCategoryData()
          : Row(
              children: [
                DonutChart(
                  segments: [
                    for (final type in CourseCategory.values)
                      DonutChartSegment(
                        value: summary.hours[type] ?? 0,
                        color: context.colors.category(type).text,
                      ),
                  ],
                  centerText:
                      '${summary.averageHours.toStringAsFixed(1)} / '
                      '${summary.averageTarget.toStringAsFixed(0)} h',
                  // Smaller than the default so "x / y h" fits.
                  centerTextStyle: context.textTheme.bodyLarge,
                  centerSubtitle: 'POR PERSONA',
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

class _NoCategoryData extends StatelessWidget {
  const _NoCategoryData();

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
          const SizedBox(height: 8),
          Text(
            'No se encontraron datos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No hay horas válidas en ninguna categoría para este período.',
            textAlign: TextAlign.center,
            style: context.textTheme.labelMedium?.copyWith(
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
      decoration: context.panel(shadow: true),
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
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium?.copyWith(
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
                  style: context.textTheme.labelSmall?.copyWith(
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
                  style: context.textTheme.labelSmall?.copyWith(
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
                  textStyle: context.textTheme.labelMedium?.copyWith(
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
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.intermediateText,
                    ),
                  ),
                ),
                Text(
                  showPercentages
                      ? '${item.value!.toStringAsFixed(1)} h (${((item.value! / total) * 100).toStringAsFixed(0)}%)'
                      : '${item.count} (${((item.count! / total) * 100).toStringAsFixed(0)}%)',
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.intermediateText,
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
