import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardMonthlyHours extends StatelessWidget {
  final AsyncValue<List<CargaDeHorasCRM>> cargasAsync;

  const DashboardMonthlyHours({super.key, required this.cargasAsync});

  @override
  Widget build(BuildContext context) {
    return cargasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Error: $error'),
      data: (cargas) {
        if (cargas.isEmpty) return const SizedBox.shrink();

        final months = _MonthlyHoursSummary.from(cargas);
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

  factory _MonthlyHoursSummary.from(List<CargaDeHorasCRM> cargas) {
    final latestDate = cargas
        .map((carga) => carga.fecha)
        .reduce((latest, date) => date.isAfter(latest) ? date : latest);
    final monthTotals = <int, double>{};
    final monthEmployees = <int, Set<String>>{};

    for (final carga in cargas) {
      final monthKey = carga.fecha.year * 12 + carga.fecha.month;
      monthTotals[monthKey] = (monthTotals[monthKey] ?? 0) + carga.horasTotales;
      monthEmployees
          .putIfAbsent(monthKey, () => <String>{})
          .add(carga.empleadoLegajo);
    }

    final points = <_MonthlyHoursPoint>[];
    for (var offset = 3; offset >= 0; offset--) {
      final date = DateTime(latestDate.year, latestDate.month - offset);
      final monthKey = date.year * 12 + date.month;
      final employees = monthEmployees[monthKey]?.length ?? 0;
      final total = monthTotals[monthKey] ?? 0;
      points.add(
        _MonthlyHoursPoint(
          label: _monthLabel(date.month),
          hours: employees == 0 ? 0 : total / employees,
        ),
      );
    }

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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolución de Horas Mensuales',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Comparativa mensual de horas promedio vs meta (8,0 h)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                  'Meta: ${summary.target.toStringAsFixed(1)} h',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
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
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Text(
                'Último mes: ',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              Text(
                '${current.toStringAsFixed(1)} h promedio',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
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
      painter: _MonthlyHoursPainter(points: points, target: target),
      child: const SizedBox.expand(),
    );
  }
}

class _MonthlyHoursPainter extends CustomPainter {
  final List<_MonthlyHoursPoint> points;
  final double target;

  const _MonthlyHoursPainter({required this.points, required this.target});

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
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final targetPaint = Paint()
      ..color = const Color(0xFF94A3B8)
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
      const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
    );

    final barWidth = chartWidth / (points.length * 2.2);
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final centerX = sidePadding + chartWidth * (index + 0.5) / points.length;
      final barHeight = chartHeight * point.hours / maxHours;
      final barTop = topPadding + chartHeight - barHeight;
      final color = index == points.length - 1
          ? const Color(0xFF2563EB)
          : const Color(0xFFCBD5E1);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth / 2, barTop, barWidth, barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      _drawCenteredText(
        canvas,
        '${point.hours.toStringAsFixed(1)} h',
        Offset(centerX, barTop - 14),
        const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
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
          color: index == points.length - 1
              ? const Color(0xFF2563EB)
              : const Color(0xFF64748B),
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
      oldDelegate.points != points || oldDelegate.target != target;
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
