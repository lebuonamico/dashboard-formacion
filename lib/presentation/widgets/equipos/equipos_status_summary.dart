import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Resumen de estados de TODOS los equipos, incluso cuando hay filtros activos.
/// Leandro: Recibe los conteos calculados por la pantalla; el semáforo de cada equipo
/// Leandro: ya fue determinado por el provider.
class EquiposStatusSummary extends StatelessWidget {
  final int total;
  final int enObjetivo;
  final int enRiesgo;
  final int criticos;

  const EquiposStatusSummary({
    super.key,
    required this.total,
    required this.enObjetivo,
    required this.enRiesgo,
    required this.criticos,
  });

  @override
  Widget build(BuildContext context) {
    // Leandro: Para este resumen, requieren atención los equipos en riesgo y los críticos.
    final requierenAtencion = enRiesgo + criticos;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: equiposPanelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = _StatusHeading(requierenAtencion: requierenAtencion);
          // Leandro: Los tres Expanded reparten por igual el ancho de los estados.
          final items = Row(
            children: [
              Expanded(
                child: _StatusItem(
                  label: 'En objetivo',
                  count: enObjetivo,
                  total: total,
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _StatusItem(
                  label: 'En riesgo',
                  count: enRiesgo,
                  total: total,
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFD97706),
                ),
              ),
              Expanded(
                child: _StatusItem(
                  label: 'Críticos',
                  count: criticos,
                  total: total,
                  icon: Icons.error_outline,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          );

          // Leandro: En anchos reducidos, el título se coloca encima de los estados.
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 18), items],
            );
          }

          return Row(
            children: [
              SizedBox(width: 260, child: heading),
              const SizedBox(width: 24),
              const SizedBox(
                height: 52,
                child: VerticalDivider(width: 1, color: equiposBorder),
              ),
              const SizedBox(width: 24),
              Expanded(child: items),
            ],
          );
        },
      ),
    );
  }
}

// Leandro: Mensaje general: adapta el texto cuando hay cero, uno o varios equipos a atender.
class _StatusHeading extends StatelessWidget {
  final int requierenAtencion;

  const _StatusHeading({required this.requierenAtencion});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado de los equipos',
          style: TextStyle(fontWeight: FontWeight.w700, color: equiposInk),
        ),
        const SizedBox(height: 5),
        Text(
          requierenAtencion == 0
              ? 'No hay equipos que requieran atención.'
              : '$requierenAtencion ${requierenAtencion == 1 ? 'equipo requiere' : 'equipos requieren'} atención.',
          style: const TextStyle(fontSize: 13, color: equiposMuted),
        ),
      ],
    );
  }
}

// Leandro: Presenta una categoría con su icono, cantidad y proporción del total de equipos.
class _StatusItem extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final IconData icon;
  final Color color;

  const _StatusItem({
    required this.label,
    required this.count,
    required this.total,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Leandro: Ejemplo: 2 equipos críticos de 5 son el 40 % de los equipos.
    // Leandro: Esta proporción no es el porcentaje de cumplimiento de sus horas.
    // Leandro: El caso total == 0 evita dividir por cero.
    final percentage = total == 0 ? 0 : (count / total * 100).round();

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 19,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: equiposInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$label · $percentage%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: equiposMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
