import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/donut_chart.dart';
import 'package:flutter/material.dart';

/// Leandro: Un segmento del donut: etiqueta, valor, color y ayuda para tooltip.
/// Leandro: backgroundColor permite que la leyenda respete el estilo del dashboard inicial.
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

/// Leandro: Combina el donut compartido con una leyenda propia de Equipos.
/// Leandro: El gráfico central viene de shared/donut_chart.dart para no duplicar diseño.
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
    // Leandro: total se usa para calcular proporciones; si es cero se dibuja sólo el aro base.
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);

    return Row(
      children: [
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
            children: [
              for (final slice in slices) ...[
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
    // Leandro: La leyenda muestra valor absoluto y porcentaje de cada segmento.
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
