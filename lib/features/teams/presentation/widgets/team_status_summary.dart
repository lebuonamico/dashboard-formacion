import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_donut_chart.dart';
import 'package:flutter/material.dart';

class TeamsStatusSummary extends StatelessWidget {
  final int total;
  final int onTarget;
  final int atRisk;
  final int critical;

  const TeamsStatusSummary({
    super.key,
    required this.total,
    required this.onTarget,
    required this.atRisk,
    required this.critical,
  });

  @override
  Widget build(BuildContext context) {
    final teamsRequiringAttention = atRisk + critical;

    final heading = _StatusHeading(
      teamsRequiringAttention: teamsRequiringAttention,
    );

    final chart = TeamDonutChart(
      centerValue: '$total',
      centerLabel: 'EQUIPOS',
      slices: [
        TeamDonutSlice(
          label: 'En objetivo',
          value: onTarget.toDouble(),
          color: context.colors.success.text,
          backgroundColor: context.colors.success.background,
          help:
              'Equipos con 100% o más de horas y todos sus integrantes cumpliendo el objetivo por categoría.',
        ),
        TeamDonutSlice(
          label: 'En riesgo',
          value: atRisk.toDouble(),
          color: context.colors.warning.text,
          backgroundColor: context.colors.warning.background,
          help:
              'Equipos con avance parcial: tienen horas suficientes o al menos algún integrante en objetivo, pero todavía presentan desvíos.',
        ),
        TeamDonutSlice(
          label: 'Críticos',
          value: critical.toDouble(),
          color: context.colors.danger.text,
          backgroundColor: context.colors.danger.background,
          help:
              'Equipos con bajo avance y sin integrantes cumpliendo el objetivo individual.',
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.panel(),
      child: Column(
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
      ),
    );
  }
}

class _StatusHeading extends StatelessWidget {
  final int teamsRequiringAttention;

  const _StatusHeading({required this.teamsRequiringAttention});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Estado de los equipos',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'Verde exige horas completas y todos los integrantes en objetivo. Riesgo y crítico indican desvíos por horas o personas.',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          teamsRequiringAttention == 0
              ? 'No hay equipos que requieran atención.'
              : '$teamsRequiringAttention ${teamsRequiringAttention == 1 ? 'equipo requiere' : 'equipos requieren'} atención.',
          style: TextStyle(
            fontSize: 13,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
