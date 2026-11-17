import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/dashboard/domain/monthly_hours.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardMonthlyHours extends StatelessWidget {
  /// Average credited hours per employee for each month, and its target.
  final AsyncValue<List<MonthlyHours>> evolutionAsync;
  final VoidCallback? onRetry;

  const DashboardMonthlyHours({
    super.key,
    required this.evolutionAsync,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return evolutionAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorDataState(
        title: 'No pudimos cargar esta sección',
        error: error,
        compact: true,
        onRetry: onRetry,
      ),
      data: (monthList) {
        if (monthList.isEmpty) {
          return const EmptyDataState(
            compact: true,
            icon: Icons.show_chart,
            title: 'No hay meses para mostrar la evolución.',
          );
        }
        return _MonthlyHoursCard(summary: _MonthlyHoursSummary.from(monthList));
      },
    );
  }
}

class _MonthlyHoursPoint {
  final int month;
  final String label;
  final double hours;

  const _MonthlyHoursPoint({
    required this.month,
    required this.label,
    required this.hours,
  });
}

class _MonthlyHoursSummary {
  final List<_MonthlyHoursPoint> points;
  final double target;

  const _MonthlyHoursSummary({required this.points, required this.target});

  factory _MonthlyHoursSummary.from(List<MonthlyHours> months) {
    final points = [
      for (final item in months)
        _MonthlyHoursPoint(
          month: item.month.month,
          label: monthName(item.month.month),
          hours: item.hours,
        ),
    ];

    return _MonthlyHoursSummary(points: points, target: months.last.target);
  }
}

class _MonthlyHoursCard extends StatefulWidget {
  final _MonthlyHoursSummary summary;

  const _MonthlyHoursCard({required this.summary});

  @override
  State<_MonthlyHoursCard> createState() => _MonthlyHoursCardState();
}

class _MonthlyHoursCardState extends State<_MonthlyHoursCard> {
  /// Narrower bars than this hide their values and shorten the months; a tap
  /// on a bar then shows its month and hours in the footer.
  static const _denseSlotWidth = 52.0;

  /// The bar tapped in the dense chart; `null` shows the last month.
  int? _selected;

  @override
  void didUpdateWidget(covariant _MonthlyHoursCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.points.length != widget.summary.points.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: context.panel(shadow: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense =
              (constraints.maxWidth - _MonthlyHoursPainter.sidePadding * 2) /
                  summary.points.length <
              _denseSlotWidth;
          final selected = dense ? _selected : null;
          final shown = summary.points[selected ?? summary.points.length - 1];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evolución de horas mensuales',
                          style: context.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Horas válidas promedio por colaborador vs objetivo '
                          '(${formatHoursPrecise(summary.target)} hs)',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Objetivo: ${formatHoursPrecise(summary.target)} hs',
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _MonthlyHoursChart(
                  points: summary.points,
                  target: summary.target,
                  dense: dense,
                  selected: selected,
                  onSelect: dense
                      ? (index) => setState(
                          () => _selected = index == _selected ? null : index,
                        )
                      : null,
                ),
              ),
              Divider(height: 16, color: context.colorScheme.outlineVariant),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      key: const Key('monthly_hours_footer'),
                      TextSpan(
                        children: [
                          TextSpan(
                            text: selected == null
                                ? 'Último mes: '
                                : '${shown.label}: ',
                          ),
                          TextSpan(
                            text:
                                '${formatHoursPrecise(shown.hours)} hs promedio',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (dense && selected == null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tocá una barra',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthlyHoursChart extends StatelessWidget {
  final List<_MonthlyHoursPoint> points;
  final double target;
  final bool dense;
  final int? selected;

  /// The bar under a tap; `null` when the bars are not tappable.
  final ValueChanged<int>? onSelect;

  const _MonthlyHoursChart({
    required this.points,
    required this.target,
    required this.dense,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final chart = CustomPaint(
      painter: _MonthlyHoursPainter(
        points: points,
        target: target,
        dense: dense,
        highlighted: selected ?? points.length - 1,
        cs: context.colorScheme,
        colors: context.colors,
        textTheme: context.textTheme,
      ),
      child: const SizedBox.expand(),
    );
    final onSelect = this.onSelect;
    if (onSelect == null) return chart;

    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        key: const Key('monthly_hours_chart'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          const side = _MonthlyHoursPainter.sidePadding;
          final slot = (constraints.maxWidth - side * 2) / points.length;
          final index = ((details.localPosition.dx - side) / slot).floor();
          onSelect(index.clamp(0, points.length - 1));
        },
        child: chart,
      ),
    );
  }
}

class _MonthlyHoursPainter extends CustomPainter {
  /// Margin at each side of the bars, also for locating a tap.
  static const sidePadding = 8.0;

  final List<_MonthlyHoursPoint> points;
  final double target;

  /// Narrow bars: short month names, and only the [highlighted] bar's value.
  final bool dense;

  /// The bar in the primary color: the last month, or the one tapped.
  final int highlighted;

  /// The painter has no BuildContext: it gets the theme colors and type.
  final ColorScheme cs;
  final AppColors colors;
  final TextTheme textTheme;

  const _MonthlyHoursPainter({
    required this.points,
    required this.target,
    required this.dense,
    required this.highlighted,
    required this.cs,
    required this.colors,
    required this.textTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 8.0;
    const bottomPadding = 24.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - sidePadding * 2;
    final maxHours =
        [
          target,
          ...points.map((point) => point.hours),
        ].reduce((max, value) => value > max ? value : max) *
        1.2;
    final scale = maxHours == 0 ? 1.0 : maxHours;

    final gridPaint = Paint()
      ..color = cs.outlineVariant
      ..strokeWidth = 1;
    final targetPaint = Paint()
      ..color = colors.faintText
      ..strokeWidth = 1;

    for (var index = 0; index <= 2; index++) {
      final y = topPadding + chartHeight * index / 2;
      canvas.drawLine(
        Offset(sidePadding, y),
        Offset(size.width - sidePadding, y),
        gridPaint,
      );
    }

    final targetY = topPadding + chartHeight * (1 - target / scale);
    canvas.drawLine(
      Offset(sidePadding, targetY),
      Offset(size.width - sidePadding, targetY),
      targetPaint,
    );
    _drawText(
      canvas,
      'Objetivo ${formatHoursPrecise(target)} hs',
      Offset(size.width - 92, targetY - 14),
      textTheme.labelSmall!.copyWith(color: cs.onSurfaceVariant),
    );

    final barWidth = chartWidth / (points.length * 2.2);
    final slotWidth = chartWidth / points.length;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final isHighlighted = index == highlighted;
      final centerX = sidePadding + chartWidth * (index + 0.5) / points.length;
      final barHeight = chartHeight * point.hours / scale;
      final barTop = topPadding + chartHeight - barHeight;
      final color = isHighlighted ? cs.primary : cs.outline;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth / 2, barTop, barWidth, barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      if (!dense || isHighlighted) {
        _drawCenteredText(
          canvas,
          '${formatHoursPrecise(point.hours)} hs',
          Offset(centerX, barTop - 14),
          textTheme.labelSmall!.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.intermediateText,
          ),
        );
      }
      _drawCenteredText(
        canvas,
        !dense
            ? point.label
            // Three letters need about 28 px; below that, the initial.
            : slotWidth >= 28
            ? monthShortName(point.month)
            : point.label.substring(0, 1),
        Offset(centerX, size.height - 10),
        textTheme.labelSmall!.copyWith(
          fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w400,
          color: isHighlighted ? cs.primary : cs.onSurfaceVariant,
        ),
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final paragraph = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    paragraph.paint(canvas, offset);
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final paragraph = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    paragraph.paint(canvas, center - Offset(paragraph.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant _MonthlyHoursPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.target != target ||
      oldDelegate.dense != dense ||
      oldDelegate.highlighted != highlighted ||
      oldDelegate.cs != cs ||
      oldDelegate.colors != colors;
}
