import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Muestra los cuatro indicadores (KPI) con los totales que recibe de la pantalla.
/// Leandro: Esta sección formatea los valores; las sumas se hacen en _DashboardContent.
class EquiposKpiSection extends StatelessWidget {
  final int totalEquipos;
  final int totalColaboradores;
  final double horasRealizadas;
  final double horasObjetivo;
  final double cumplimientoGlobal;

  const EquiposKpiSection({
    super.key,
    required this.totalEquipos,
    required this.totalColaboradores,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.cumplimientoGlobal,
  });

  @override
  Widget build(BuildContext context) {
    // Leandro: Cada _KpiData describe una tarjeta: etiqueta, valor, detalle, icono y color.
    // Leandro: toStringAsFixed(1) convierte las horas o el porcentaje a texto con un decimal.
    return _KpiGrid(
      items: [
        _KpiData(
          title: 'Equipos activos',
          value: '$totalEquipos',
          detail: 'en seguimiento',
          icon: Icons.groups_outlined,
          color: equiposBrand,
        ),
        _KpiData(
          title: 'Colaboradores',
          value: '$totalColaboradores',
          detail: 'en todos los equipos',
          icon: Icons.people_outline,
          color: const Color(0xFF0E7490),
        ),
        _KpiData(
          title: 'Horas realizadas',
          value: horasRealizadas.toStringAsFixed(1),
          detail: 'de ${horasObjetivo.toStringAsFixed(1)} hs objetivo',
          icon: Icons.schedule_outlined,
          color: const Color(0xFF6941C6),
        ),
        _KpiData(
          title: 'Cumplimiento global',
          value: '${cumplimientoGlobal.toStringAsFixed(1)}%',
          detail: cumplimientoGlobal >= 100
              ? 'objetivo alcanzado'
              : 'avance acumulado',
          icon: Icons.trending_up,
          color: cumplimientoGlobal >= 100
              ? const Color(0xFF16A34A)
              : const Color(0xFFD97706),
        ),
      ],
    );
  }
}

// Leandro: Objeto de presentación interno: reúne los datos que necesita una tarjeta KPI.
// Leandro: El prefijo _ mantiene esta clase privada a la biblioteca de este archivo.
class _KpiData {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

// Leandro: Distribuye los indicadores según el ancho que le deja su widget padre.
class _KpiGrid extends StatelessWidget {
  final List<_KpiData> items;

  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leandro: Elegimos 4, 2 o 1 columnas. Restamos los espacios antes de dividir
        // Leandro: el ancho para que todas las tarjetas de la fila midan lo mismo.
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 14) / columns;

        // Leandro: Wrap permite pasar a la fila siguiente; map crea un widget por indicador.
        // Leandro: La altura común de 116 mantiene alineadas las tarjetas.
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

// Leandro: Dibuja un indicador: icono a la izquierda y título, valor y detalle a la derecha.
// Leandro: Expanded deja al texto el espacio restante de la fila; ellipsis limita desbordes.
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
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: equiposMuted,
                  ),
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
