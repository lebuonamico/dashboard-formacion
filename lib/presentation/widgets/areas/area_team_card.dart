import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:go_router/go_router.dart';

/// Grilla de los equipos generales de un área, con título y conteo.
class AreaEquiposGrid extends StatelessWidget {
  final List<TeamOverview> equipos;
  final bool esAnual;
  final String origen;

  const AreaEquiposGrid({
    super.key,
    required this.equipos,
    required this.origen,
    this.esAnual = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Equipos del área',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: equipos.length),
          ],
        ),
        const SizedBox(height: 13),
        if (equipos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: context.panel(),
            child: Text(
              'No hay equipos generales asignados.',
              style: TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 410,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 252,
            ),
            itemCount: equipos.length,
            itemBuilder: (context, index) => AreaEquipoCard(
              equipo: equipos[index],
              esAnual: esAnual,
              origen: origen,
            ),
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Tarjeta de un equipo dentro del detalle de área, con el estilo de la
/// pantalla de Equipos.
class AreaEquipoCard extends StatelessWidget {
  final TeamOverview equipo;
  final bool esAnual;

  /// Sección del menú desde la que se llegó, para que el detalle la resalte.
  final String origen;

  const AreaEquipoCard({
    super.key,
    required this.equipo,
    required this.origen,
    this.esAnual = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (equipo.completionPercentage / 100).clamp(0.0, 1.0);
    final colorEstado = equipo.status.colores(context).texto;

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(
          '/areas/${Uri.encodeComponent(equipo.area)}/equipos/${Uri.encodeComponent(equipo.name)}?origen=$origen',
        ),
        child: Container(
          decoration: context.panel(sombra: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: colorEstado,
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
                      _CardHeader(equipo: equipo),
                      const SizedBox(height: 13),
                      _LeaderRow(lider: equipo.leader),
                      const Spacer(),
                      _ProgressSection(
                        equipo: equipo,
                        progress: progress,
                        esAnual: esAnual,
                      ),
                      const SizedBox(height: 9),
                      _CardFooter(equipo: equipo),
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
  final TeamOverview equipo;

  const _CardHeader({required this.equipo});

  @override
  Widget build(BuildContext context) {
    final integrantes = equipo.memberCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                equipo.name,
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
              // El área ya es el título de la pantalla: acá va la nómina.
              Text(
                '$integrantes ${integrantes == 1 ? 'integrante' : 'integrantes'}',
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
        _StatusBadge(status: equipo.status),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final String lider;

  const _LeaderRow({required this.lider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.person_outline,
          size: 16,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Líder: $lider',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final TeamOverview equipo;
  final double progress;
  final bool esAnual;

  const _ProgressSection({
    required this.equipo,
    required this.progress,
    required this.esAnual,
  });

  @override
  Widget build(BuildContext context) {
    final colorEstado = equipo.status.colores(context).texto;

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
                      '${equipo.membersOnTarget} de ${equipo.memberCount} en objetivo',
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
                    message: esAnual
                        ? 'Colaboradores que tuvieron objetivo en este equipo durante al menos uno de los meses con datos del año.'
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
              formatearPorcentaje(equipo.completionPercentage),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorEstado,
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
            backgroundColor: context.colores.graficoPista,
            color: colorEstado,
          ),
        ),
      ],
    );
  }
}

class _CardFooter extends StatelessWidget {
  final TeamOverview equipo;

  const _CardFooter({required this.equipo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '${equipo.completedHours.toStringAsFixed(1)} de ${equipo.targetHours.toStringAsFixed(1)} hs',
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
                _formatDesvio(equipo.hoursDeviation),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: equipo.hoursDeviation >= 0
                      ? context.colores.exito.texto
                      : context.colores.peligro.texto,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Ver detalle',
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

  String _formatDesvio(double desvioHoras) {
    if (desvioHoras >= 0) {
      return '+${desvioHoras.toStringAsFixed(1)} hs';
    }

    return '-${desvioHoras.abs().toStringAsFixed(1)} hs';
  }
}

class _StatusBadge extends StatelessWidget {
  final TeamStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final ParColores(:texto, :fondo) = status.colores(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: texto, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: texto,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
