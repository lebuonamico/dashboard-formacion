import 'package:app_finnegans/presentation/widgets/teams/team_donut_chart.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:flutter/material.dart';

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
    final requierenAtencion = enRiesgo + criticos;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: equiposPanelDecoration(),
      child: Builder(
        builder: (context) {
          // Leandro: llama a _StatusHeading para indicar cuántos equipos requieren atención.
          final heading = _StatusHeading(requierenAtencion: requierenAtencion);
          // Leandro: llama a EquiposDonutChart para mostrar la distribución de estados de los equipos.
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

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 44, child: heading),
              const SizedBox(height: 12),
              Flexible(
                fit: FlexFit.loose,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 166),
                  child: Center(child: chart),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
