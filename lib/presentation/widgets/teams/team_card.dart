import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EquipoCard extends StatelessWidget {
  final EquipoGlobalViewModel equipo;
  final bool esAnual;

  const EquipoCard({super.key, required this.equipo, this.esAnual = false});

  @override
  Widget build(BuildContext context) {
    final progress = (equipo.porcentajeCumplimiento / 100).clamp(0.0, 1.0);

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // Leandro: llama a context.push para abrir el detalle del equipo al tocar la tarjeta.
        onTap: () => context.push(
          '/areas/${Uri.encodeComponent(equipo.area)}/equipos/${Uri.encodeComponent(equipo.nombre)}?origen=equipos',
        ),
        child: Container(
          decoration: context.panel(sombra: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: equipo.estado.colores(context).texto,
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
                      // Leandro: llama a _CardHeader para mostrar el nombre, área y estado del equipo.
                      _CardHeader(equipo: equipo),
                      const SizedBox(height: 13),
                      // Leandro: llama a _LeaderRow para mostrar el líder del equipo.
                      _LeaderRow(lider: equipo.lider),
                      const Spacer(),
                      // Leandro: llama a _ProgressSection para mostrar integrantes en objetivo y avance de horas.
                      _ProgressSection(
                        equipo: equipo,
                        progress: progress,
                        esAnual: esAnual,
                      ),
                      const SizedBox(height: 9),
                      // Leandro: llama a _CardFooter para mostrar las horas realizadas y el desvío.
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
  final EquipoGlobalViewModel equipo;

  const _CardHeader({required this.equipo});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                equipo.nombre,
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
                equipo.area,
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
        // Leandro: llama a _StatusBadge para mostrar la insignia del estado del equipo.
        _StatusBadge(status: equipo.estado),
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
  final EquipoGlobalViewModel equipo;
  final double progress;
  final bool esAnual;

  const _ProgressSection({
    required this.equipo,
    required this.progress,
    required this.esAnual,
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
                      '${equipo.integrantesEnObjetivo} de ${equipo.cantidadIntegrantes} en objetivo',
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
              formatearPorcentaje(equipo.porcentajeCumplimiento),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: equipo.estado.colores(context).texto,
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
            color: equipo.estado.colores(context).texto,
          ),
        ),
      ],
    );
  }
}

class _CardFooter extends StatelessWidget {
  final EquipoGlobalViewModel equipo;

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
                  '${equipo.horasRealizadas.toStringAsFixed(1)} de ${equipo.horasObjetivo.toStringAsFixed(1)} hs',
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
                // Leandro: llama a _formatDesvio para mostrar las horas faltantes o excedentes del equipo.
                _formatDesvio(equipo.desvioHoras),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: equipo.desvioHoras >= 0
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
  final EstadoEquipo status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.colores(context).fondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.colores(context).texto,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.colores(context).texto,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
