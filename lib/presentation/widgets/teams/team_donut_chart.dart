import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/donut_chart.dart';
import 'package:flutter/material.dart';

class EquiposDonutSlice {
  final String label;
  final double value;
  final Color color;
  final Color backgroundColor;
  final String help;

  const EquiposDonutSlice({
    required this.label,
    required this.value,
    required this.color,
    this.backgroundColor = const Color(0xFFF8FAFC),
    required this.help,
  });
}

class EquiposDonutChart extends StatelessWidget {
  final List<EquiposDonutSlice> slices;
  final String centerValue;
  final String centerLabel;
  final String valueSuffix;

  const EquiposDonutChart({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
    this.valueSuffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);

    return Row(
      children: [
        // Leandro: llama a DonutChart para representar los segmentos del resumen.
        DonutChart(
          segments: slices
              .map(
                (slice) =>
                    DonutChartSegment(value: slice.value, color: slice.color),
              )
              .toList(),
          centerText: centerValue,
          centerSubtitle: centerLabel,
          centerTextSize: 24,
          centerSubtitleSize: 11,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slice in slices) ...[
                // Leandro: llama a _DonutLegendItem para mostrar el valor y porcentaje de cada segmento.
                _DonutLegendItem(
                  slice: slice,
                  total: total,
                  valueSuffix: valueSuffix,
                ),
                if (slice != slices.last) const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutLegendItem extends StatelessWidget {
  final EquiposDonutSlice slice;
  final double total;
  final String valueSuffix;

  const _DonutLegendItem({
    required this.slice,
    required this.total,
    required this.valueSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total == 0 ? 0 : (slice.value / total * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: slice.backgroundColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Tooltip(
            message: slice.help,
            child: Icon(
              Icons.info_outline,
              size: 15,
              color: equiposMuted.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatValue(slice.value)}$valueSuffix ($percentage%)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}
