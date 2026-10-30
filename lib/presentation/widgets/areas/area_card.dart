import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:go_router/go_router.dart';

class AreaCard extends StatelessWidget {
  final AreaGlobalViewModel area;
  final bool isAnnual;

  /// Sección del menú desde la que se llegó, para que el detalle la resalte.
  final String? origin;

  const AreaCard({
    super.key,
    required this.area,
    this.isAnnual = false,
    this.origin,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (area.compliancePercentage / 100).clamp(0.0, 1.0);
    final destination = '/areas/${Uri.encodeComponent(area.name)}';

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(
          origin == null ? destination : '$destination?origen=$origin',
        ),
        child: Container(
          decoration: context.panel(shadow: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: area.level.colors(context).text,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardHeader(area: area),
                      const SizedBox(height: 13),
                      _TeamsRow(teams: area.generalTeams),
                      if (area.leaders != null) ...[
                        const SizedBox(height: 6),
                        _LeadersRow(leaders: area.leaders!),
                      ],
                      const Spacer(),
                      _ProgressSection(
                        area: area,
                        progress: progress,
                        isAnnual: isAnnual,
                      ),
                      const SizedBox(height: 9),
                      _CardFooter(area: area),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final AreaGlobalViewModel area;

  const _CardHeader({required this.area});

  @override
  Widget build(BuildContext context) {
    final employees = area.memberCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                area.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$employees ${employees == 1 ? 'colaborador' : 'colaboradores'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusBadge(trafficLight: area.level),
      ],
    );
  }
}

/// En el lugar del líder de Equipos: los equipos generales del área.
class _TeamsRow extends StatelessWidget {
  final List<String> teams;

  const _TeamsRow({required this.teams});

  @override
  Widget build(BuildContext context) {
    final text = teams.isEmpty
        ? 'Sin equipo general asignado'
        : 'Equipos: ${teams.join(', ')}';

    return Row(
      children: [
        Icon(
          Icons.groups_outlined,
          size: 16,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Tooltip(
            message: text,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Líderes de área asignados en el panel de administración.
class _LeadersRow extends StatelessWidget {
  final String leaders;

  const _LeadersRow({required this.leaders});

  @override
  Widget build(BuildContext context) {
    final text = 'Líder de área: $leaders';

    return Row(
      children: [
        Icon(
          Icons.person_outline,
          size: 16,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Tooltip(
            message: text,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final AreaGlobalViewModel area;
  final double progress;
  final bool isAnnual;

  const _ProgressSection({
    required this.area,
    required this.progress,
    required this.isAnnual,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${area.membersOnTarget} de ${area.memberCount} en objetivo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Tooltip(
                    message: isAnnual
                        ? 'Colaboradores que tuvieron objetivo en esta área durante al menos uno de los meses con datos del año.'
                        : 'Personas que cumplen su plan por categoría. El porcentaje de la derecha compara horas realizadas contra objetivo.',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPercentage(area.compliancePercentage),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: area.level.colors(context).text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: context.colors.chartTrack,
            color: area.level.colors(context).text,
          ),
        ),
      ],
    );
  }
}

class _CardFooter extends StatelessWidget {
  final AreaGlobalViewModel area;

  const _CardFooter({required this.area});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '${area.completedHours.toStringAsFixed(1)} de ${area.targetHours.toStringAsFixed(1)} hs',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDeviation(area.hoursDeviation),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: area.hoursDeviation >= 0
                      ? context.colors.success.text
                      : context.colors.danger.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Ver área',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.arrow_forward_rounded,
          size: 15,
          color: context.colorScheme.primary,
        ),
      ],
    );
  }

  String _formatDeviation(double hoursDeviation) {
    if (hoursDeviation >= 0) {
      return '+${hoursDeviation.toStringAsFixed(1)} hs';
    }

    return '-${hoursDeviation.abs().toStringAsFixed(1)} hs';
  }
}

class _StatusBadge extends StatelessWidget {
  final ComplianceLevel trafficLight;

  const _StatusBadge({required this.trafficLight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: trafficLight.colors(context).background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: trafficLight.colors(context).text,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            trafficLight.label,
            style: TextStyle(
              color: trafficLight.colors(context).text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
