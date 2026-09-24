import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Leandro: Segmento reutilizable para gráficos donut de la app.
/// Leandro: Sólo guarda valor y color; la leyenda la define cada pantalla.
class DonutChartSegment {
  final double value;
  final Color color;

  const DonutChartSegment({required this.value, required this.color});
}

/// Leandro: Donut visual compartido por Dashboard y Equipos.
/// Leandro: Centraliza tamaño, trazo y geometría para evitar diseños distintos.
class DonutChart extends StatelessWidget {
  final List<DonutChartSegment> segments;
  final String centerText;
  final String centerSubtitle;
  final double centerTextSize;
  final double centerSubtitleSize;

  const DonutChart({
    super.key,
    required this.segments,
    required this.centerText,
    required this.centerSubtitle,
    this.centerTextSize = 20,
    this.centerSubtitleSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: CustomPaint(
        painter: _DonutPainter(segments),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerText,
                style: TextStyle(
                  fontSize: centerTextSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                centerSubtitle,
                style: TextStyle(
                  fontSize: centerSubtitleSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutChartSegment> segments;

  const _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    const strokeWidth = 16.0;
    final total = segments.fold<double>(
      0,
      (sum, segment) => sum + segment.value,
    );
    final backgroundPaint = Paint()
      ..color = const Color(0xFFE8EEF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);
    if (total == 0) return;

    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value == 0) continue;
      final sweepAngle = (segment.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}
