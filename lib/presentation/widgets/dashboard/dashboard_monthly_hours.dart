import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardMonthlyHours extends StatelessWidget {
  /// Horas válidas promedio por colaborador de cada mes.
  final AsyncValue<List<({DateTime mes, double horas})>> evolucionAsync;

  const DashboardMonthlyHours({super.key, required this.evolucionAsync});

  @override
  Widget build(BuildContext context) {
    return evolucionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorDataState(
        title: 'No pudimos cargar esta sección',
        error: error,
        compact: true,
      ),
      data: (meses) {
        if (meses.isEmpty) return const SizedBox.shrink();

        final months = _MonthlyHoursSummary.from(meses);
        return _MonthlyHoursCard(summary: months);
      },
    );
  }
}

class _MonthlyHoursPoint {
  final String label;
  final double hours;

  const _MonthlyHoursPoint({required this.label, required this.hours});
}

class _MonthlyHoursSummary {
  final List<_MonthlyHoursPoint> points;
  final double target;

  const _MonthlyHoursSummary({required this.points, required this.target});

  factory _MonthlyHoursSummary.from(
    List<({DateTime mes, double horas})> meses,
  ) {
    final points = [
      for (final item in meses)
        _MonthlyHoursPoint(
          label: _monthLabel(item.mes.month),
          hours: item.horas,
        ),
    ];

    return _MonthlyHoursSummary(points: points, target: 8);
  }
}

class _MonthlyHoursCard extends StatelessWidget {
  final _MonthlyHoursSummary summary;

  const _MonthlyHoursCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final current = summary.points.last.hours;

    return Container(
      height: 280,
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
                      'Evolución de horas mensuales',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Horas válidas promedio por colaborador vs meta (8,0 h)',
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
                  'Meta: ${summary.target.toStringAsFixed(1)} h',
                  style: TextStyle(
                    fontSize: 10,
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
            ),
          ),
          Divider(height: 16, color: context.colorScheme.outlineVariant),
          Row(
            children: [
              Text(
                'Último mes: ',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${current.toStringAsFixed(1)} h promedio',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyHoursChart extends StatelessWidget {
  final List<_MonthlyHoursPoint> points;
  final double target;

  const _MonthlyHoursChart({required this.points, required this.target});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MonthlyHoursPainter(
        points: points,
        target: target,
        cs: context.colorScheme,
        colores: context.colores,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MonthlyHoursPainter extends CustomPainter {
  final List<_MonthlyHoursPoint> points;
  final double target;

  /// El painter no tiene BuildContext: recibe los colores del tema activo.
  final ColorScheme cs;
  final AppColors colores;

  const _MonthlyHoursPainter({
    required this.points,
    required this.target,
    required this.cs,
    required this.colores,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 8.0;
    const bottomPadding = 24.0;
    const sidePadding = 8.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - sidePadding * 2;
    final maxHours =
        [
          target,
          ...points.map((point) => point.hours),
        ].reduce((max, value) => value > max ? value : max) *
        1.2;

    final gridPaint = Paint()
      ..color = cs.outlineVariant
      ..strokeWidth = 1;
    final targetPaint = Paint()
      ..color = colores.textoTenue
      ..strokeWidth = 1;

    for (var index = 0; index <= 2; index++) {
      final y = topPadding + chartHeight * index / 2;
      canvas.drawLine(
        Offset(sidePadding, y),
        Offset(size.width - sidePadding, y),
        gridPaint,
      );
    }

    final targetY = topPadding + chartHeight * (1 - target / maxHours);
    canvas.drawLine(
      Offset(sidePadding, targetY),
      Offset(size.width - sidePadding, targetY),
      targetPaint,
    );
    _drawText(
      canvas,
      'Meta ${target.toStringAsFixed(1)} h',
      Offset(size.width - 66, targetY - 14),
      TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
    );

    final barWidth = chartWidth / (points.length * 2.2);
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final centerX = sidePadding + chartWidth * (index + 0.5) / points.length;
      final barHeight = chartHeight * point.hours / maxHours;
      final barTop = topPadding + chartHeight - barHeight;
      final color = index == points.length - 1 ? cs.primary : cs.outline;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth / 2, barTop, barWidth, barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      _drawCenteredText(
        canvas,
        '${point.hours.toStringAsFixed(1)} h',
        Offset(centerX, barTop - 14),
        TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colores.textoIntermedio,
        ),
      );
      _drawCenteredText(
        canvas,
        point.label,
        Offset(centerX, size.height - 10),
        TextStyle(
          fontSize: 10,
          fontWeight: index == points.length - 1
              ? FontWeight.w700
              : FontWeight.w400,
          color: index == points.length - 1 ? cs.primary : cs.onSurfaceVariant,
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
      oldDelegate.cs != cs ||
      oldDelegate.colores != colores;
}

String _monthLabel(int month) {
  const labels = [
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
  return labels[month - 1];
}
