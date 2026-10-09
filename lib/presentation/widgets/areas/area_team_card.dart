import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Colores del estado de un equipo, los mismos que usa la pantalla de Equipos.
(Color texto, Color fondo) _coloresEstado(EstadoEquipo estado) {
  switch (estado) {
    case EstadoEquipo.enObjetivo:
      return (const Color(0xFF16A34A), const Color(0xFFDCFCE7));
    case EstadoEquipo.enRiesgo:
      return (const Color(0xFFD97706), const Color(0xFFFEF3C7));
    case EstadoEquipo.critico:
      return (const Color(0xFFDC2626), const Color(0xFFFEE2E2));
  }
}

/// Grilla de los equipos generales de un área, con título y conteo.
class AreaEquiposGrid extends StatelessWidget {
  final List<EquipoGlobalViewModel> equipos;
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
            const Text(
              'Equipos del área',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: areasInk,
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
            decoration: areasPanelDecoration(),
            child: const Text(
              'No hay equipos generales asignados.',
              style: TextStyle(color: areasMuted),
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
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: areasBrand,
        ),
      ),
    );
  }
}

/// Tarjeta de un equipo dentro del detalle de área, con el estilo de la
/// pantalla de Equipos.
class AreaEquipoCard extends StatelessWidget {
  final EquipoGlobalViewModel equipo;
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
    final progress = (equipo.porcentajeCumplimiento / 100).clamp(0.0, 1.0);
    final (colorEstado, _) = _coloresEstado(equipo.estado);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(
          '/areas/${Uri.encodeComponent(equipo.area)}/equipos/${Uri.encodeComponent(equipo.nombre)}?origen=$origen',
        ),
        child: Container(
          decoration: areasPanelDecoration(withShadow: true),
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
                      _LeaderRow(lider: equipo.lider),
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
  final EquipoGlobalViewModel equipo;

  const _CardHeader({required this.equipo});

  @override
  Widget build(BuildContext context) {
    final integrantes = equipo.cantidadIntegrantes;

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
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: areasInk,
                ),
              ),
              const SizedBox(height: 5),
              // El área ya es el título de la pantalla: acá va la nómina.
              Text(
                '$integrantes ${integrantes == 1 ? 'integrante' : 'integrantes'}',
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
        const Icon(Icons.person_outline, size: 16, color: areasMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Líder: $lider',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: areasMuted),
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
    final (colorEstado, _) = _coloresEstado(equipo.estado);

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
                      style: const TextStyle(fontSize: 12, color: areasMuted),
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
                      color: areasMuted.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${equipo.porcentajeCumplimiento.toStringAsFixed(0)}%',
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
            backgroundColor: const Color(0xFFEAECF0),
            color: colorEstado,
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: areasInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDesvio(equipo.desvioHoras),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: equipo.desvioHoras >= 0
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Ver detalle',
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
  final EstadoEquipo status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (texto, fondo) = _coloresEstado(status);

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
