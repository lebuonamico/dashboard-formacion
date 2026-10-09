import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:flutter/material.dart';
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            context.push(origen == null ? destino : '$destino?origen=$origen'),
        child: Container(
          decoration: areasPanelDecoration(withShadow: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: area.semaforo.colorTexto,
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
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: areasInk,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$colaboradores ${colaboradores == 1 ? 'colaborador' : 'colaboradores'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: areasBrand,
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
        const Icon(Icons.groups_outlined, size: 16, color: areasMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Tooltip(
            message: texto,
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: areasMuted),
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
                      style: const TextStyle(fontSize: 12, color: areasMuted),
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
                      color: areasMuted.withValues(alpha: 0.75),
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
                color: area.semaforo.colorTexto,
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
            backgroundColor: const Color(0xFFEAECF0),
            color: area.semaforo.colorTexto,
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: areasInk,
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
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Ver área',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: areasBrand,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_rounded, size: 15, color: areasBrand),
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
        color: semaforo.colorFondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: semaforo.colorTexto,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            semaforo.label,
            style: TextStyle(
              color: semaforo.colorTexto,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
