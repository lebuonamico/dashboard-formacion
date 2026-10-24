import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:go_router/go_router.dart';

class AreaCard extends StatelessWidget {
  final AreaGlobalViewModel area;
  final bool esAnual;

  /// Sección del menú desde la que se llegó, para que el detalle la resalte.
  final String? origen;

  const AreaCard({
    super.key,
    required this.area,
    this.esAnual = false,
    this.origen,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (area.porcentajeCumplimiento / 100).clamp(0.0, 1.0);
    final destino = '/areas/${Uri.encodeComponent(area.nombre)}';

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            context.push(origen == null ? destino : '$destino?origen=$origen'),
        child: Container(
          decoration: context.panel(sombra: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: area.semaforo.colores(context).texto,
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
                      _EquiposRow(equipos: area.equiposGenerales),
                      if (area.lideres != null) ...[
                        const SizedBox(height: 6),
                        _LideresRow(lideres: area.lideres!),
                      ],
                      const Spacer(),
                      _ProgressSection(
                        area: area,
                        progress: progress,
                        esAnual: esAnual,
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
    final colaboradores = area.cantidadIntegrantes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                area.nombre,
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
                '$colaboradores ${colaboradores == 1 ? 'colaborador' : 'colaboradores'}',
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
        _StatusBadge(semaforo: area.semaforo),
      ],
    );
  }
}

/// En el lugar del líder de Equipos: los equipos generales del área.
class _EquiposRow extends StatelessWidget {
  final List<String> equipos;

  const _EquiposRow({required this.equipos});

  @override
  Widget build(BuildContext context) {
    final texto = equipos.isEmpty
        ? 'Sin equipo general asignado'
        : 'Equipos: ${equipos.join(', ')}';

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
            message: texto,
            child: Text(
              texto,
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
class _LideresRow extends StatelessWidget {
  final String lideres;

  const _LideresRow({required this.lideres});

  @override
  Widget build(BuildContext context) {
    final texto = 'Líder de área: $lideres';

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
            message: texto,
            child: Text(
              texto,
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
  final bool esAnual;

  const _ProgressSection({
    required this.area,
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
                      '${area.integrantesEnObjetivo} de ${area.cantidadIntegrantes} en objetivo',
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
              '${area.porcentajeCumplimiento.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: area.semaforo.colores(context).texto,
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
            color: area.semaforo.colores(context).texto,
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
                  '${area.horasRealizadas.toStringAsFixed(1)} de ${area.horasObjetivo.toStringAsFixed(1)} hs',
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
                _formatDesvio(area.desvioHoras),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: area.desvioHoras >= 0
                      ? context.colores.exito.texto
                      : context.colores.peligro.texto,
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

  String _formatDesvio(double desvioHoras) {
    if (desvioHoras >= 0) {
      return '+${desvioHoras.toStringAsFixed(1)} hs';
    }

    return '-${desvioHoras.abs().toStringAsFixed(1)} hs';
  }
}

class _StatusBadge extends StatelessWidget {
  final EstadoSemaforo semaforo;

  const _StatusBadge({required this.semaforo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: semaforo.colores(context).fondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: semaforo.colores(context).texto,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            semaforo.label,
            style: TextStyle(
              color: semaforo.colores(context).texto,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
