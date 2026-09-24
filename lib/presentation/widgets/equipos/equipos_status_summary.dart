import 'package:app_finnegans/presentation/widgets/equipos/equipos_donut_chart.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Donut de estados. Recibe los conteos de todos los equipos desde EquiposScreen.
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
    // Leandro: Requieren atención los equipos en riesgo y los críticos.
    final requierenAtencion = enRiesgo + criticos;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: equiposPanelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = _StatusHeading(requierenAtencion: requierenAtencion);
          final chart = EquiposDonutChart(
            centerValue: '$total',
            centerLabel: 'EQUIPOS',
            slices: [
              EquiposDonutSlice(
                label: 'En objetivo',
                value: enObjetivo.toDouble(),
                color: const Color(0xFF009B61),
                backgroundColor: const Color(0xFFECFDF5),
                help:
                    'Equipos con 100% o más de horas y todos sus integrantes cumpliendo el objetivo por categoría.',
              ),
              EquiposDonutSlice(
                label: 'En riesgo',
                value: enRiesgo.toDouble(),
                color: const Color(0xFFF59E0B),
                backgroundColor: const Color(0xFFFFFBEB),
                help:
                    'Equipos con avance parcial: tienen horas suficientes o al menos algún integrante en objetivo, pero todavía presentan desvíos.',
              ),
              EquiposDonutSlice(
                label: 'Críticos',
                value: criticos.toDouble(),
                color: const Color(0xFFF43F5E),
                backgroundColor: const Color(0xFFFFF1F2),
                help:
                    'Equipos con bajo avance y sin integrantes cumpliendo el objetivo individual.',
              ),
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 18), chart],
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
              Expanded(child: chart),
            ],
          );
        },
      ),
    );
  }
}

// Leandro: Mensaje que resume cuántos equipos requieren atención.
class _StatusHeading extends StatelessWidget {
  final int requierenAtencion;

  const _StatusHeading({required this.requierenAtencion});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Estado de los equipos',
              style: TextStyle(fontWeight: FontWeight.w700, color: equiposInk),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'Verde exige horas completas y todos los integrantes en objetivo. Riesgo y crítico indican desvíos por horas o personas.',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: equiposMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
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
