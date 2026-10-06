import 'package:flutter/material.dart';

class KpiData {
  final String title;
  final String value;
  final String detail;
  final String? help;
  final IconData icon;
  final Color color;

  const KpiData({
    required this.title,
    required this.value,
    required this.detail,
    this.help,
    required this.icon,
    required this.color,
  });
}

class KpiGrid extends StatelessWidget {
  final List<KpiData> items;
  final double cardHeight;

  const KpiGrid({super.key, required this.items, this.cardHeight = 116});

  @override
  Widget build(BuildContext context) {
    // Leandro: llama a LayoutBuilder para ajustar las columnas de KPIs al ancho disponible.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 14) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  // Leandro: llama a _KpiCard para mostrar el valor y el detalle de cada indicador.
                  child: _KpiCard(data: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    if (data.help != null) ...[
                      const SizedBox(width: 4),
                      // Leandro: llama a Tooltip para mostrar la ayuda asociada al indicador.
                      Tooltip(
                        message: data.help!,
                        child: const Icon(
                          Icons.info_outline,
                          size: 15,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
