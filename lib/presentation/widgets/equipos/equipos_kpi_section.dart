import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Muestra los KPI calculados por _DashboardContent en EquiposScreen.
class EquiposKpiSection extends StatelessWidget {
  final int totalEquipos;
  final int totalColaboradores;
  final double horasRealizadas;
  final double horasObjetivo;
  final double desvioHoras;
  final double cumplimientoGlobal;

  const EquiposKpiSection({
    super.key,
    required this.totalEquipos,
    required this.totalColaboradores,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.desvioHoras,
    required this.cumplimientoGlobal,
  });

  @override
  Widget build(BuildContext context) {
    return _KpiGrid(
      items: [
        _KpiData(
          title: 'Equipos activos',
          value: '$totalEquipos',
          detail: 'en seguimiento',
          help:
              'Cantidad de equipos detectados al agrupar colaboradores por área y equipo general.',
          icon: Icons.groups_outlined,
          color: equiposBrand,
        ),
        _KpiData(
          title: 'Colaboradores',
          value: '$totalColaboradores',
          detail: 'en todos los equipos',
          help:
              'Suma de integrantes de todos los equipos incluidos en el mes y año seleccionados.',
          icon: Icons.people_outline,
          color: const Color(0xFF0E7490),
        ),
        _KpiData(
          title: 'Horas realizadas',
          value: horasRealizadas.toStringAsFixed(1),
          detail: _formatDesvio(desvioHoras),
          help:
              'Suma de horas cargadas en CRM para el mes/año seleccionado. El detalle compara realizadas contra objetivo.',
          icon: Icons.schedule_outlined,
          color: desvioHoras >= 0
              ? const Color(0xFF16A34A)
              : const Color(0xFF6941C6),
        ),
        _KpiData(
          title: 'Cumplimiento global',
          value: '${cumplimientoGlobal.toStringAsFixed(1)}%',
          detail: cumplimientoGlobal >= 100
              ? 'objetivo alcanzado'
              : 'avance acumulado',
          help:
              'Horas realizadas totales dividido horas objetivo totales. No es un promedio simple de equipos.',
          icon: Icons.trending_up,
          color: cumplimientoGlobal >= 100
              ? const Color(0xFF16A34A)
              : const Color(0xFFD97706),
        ),
      ],
    );
  }

  String _formatDesvio(double desvioHoras) {
    if (desvioHoras >= 0) {
      return '+${desvioHoras.toStringAsFixed(1)} hs sobre objetivo';
    }

    return 'faltan ${desvioHoras.abs().toStringAsFixed(1)} hs';
  }
}

// Leandro: Datos visuales que necesita cada tarjeta KPI.
class _KpiData {
  final String title;
  final String value;
  final String detail;
  final String help;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.title,
    required this.value,
    required this.detail,
    required this.help,
    required this.icon,
    required this.color,
  });
}

// Leandro: Distribuye los KPI en 4, 2 o 1 columnas según el ancho disponible.
class _KpiGrid extends StatelessWidget {
  final List<_KpiData> items;

  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
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
                  height: 116,
                  child: _KpiCard(data: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// Leandro: Presentación de una tarjeta KPI individual.
class _KpiCard extends StatelessWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: equiposPanelDecoration(withShadow: true),
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
                          color: equiposMuted,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: data.help,
                      child: Icon(
                        Icons.info_outline,
                        size: 15,
                        color: equiposMuted.withValues(alpha: 0.75),
                      ),
                    ),
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
                    color: equiposInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: equiposMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
