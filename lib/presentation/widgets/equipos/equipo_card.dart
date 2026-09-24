import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/equipos/estado_equipo_style.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Leandro: Tarjeta llamada desde EquiposResults para mostrar un equipo calculado.
class EquipoCard extends StatelessWidget {
  final EquipoGlobalViewModel equipo;

  const EquipoCard({super.key, required this.equipo});

  @override
  Widget build(BuildContext context) {
    // Leandro: La barra se limita visualmente al 100 %, aunque el dato pueda superarlo.
    final progress = (equipo.porcentajeCumplimiento / 100).clamp(0.0, 1.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // Leandro: Al tocar la tarjeta navega al detalle usando área y equipo en la ruta.
        onTap: () => context.push(
          '/areas/${Uri.encodeComponent(equipo.area)}/equipos/${Uri.encodeComponent(equipo.nombre)}',
        ),
        child: Container(
          decoration: equiposPanelDecoration(withShadow: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: equipo.estado.colorTexto,
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
                      _ProgressSection(equipo: equipo, progress: progress),
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

// Leandro: Cabecera con nombre, área y estado del equipo.
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
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: equiposInk,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                equipo.area,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: equiposBrand,
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

// Leandro: Fila visual con el líder informado por Nómina.
class _LeaderRow extends StatelessWidget {
  final String lider;

  const _LeaderRow({required this.lider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 16, color: equiposMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Líder: $lider',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: equiposMuted),
          ),
        ),
      ],
    );
  }
}

// Leandro: Muestra cumplimiento individual y avance agregado de horas.
class _ProgressSection extends StatelessWidget {
  final EquipoGlobalViewModel equipo;
  final double progress;

  const _ProgressSection({required this.equipo, required this.progress});

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
                      style: const TextStyle(fontSize: 12, color: equiposMuted),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Tooltip(
                    message:
                        'Personas que cumplen su plan por categoría. El porcentaje de la derecha compara horas realizadas contra objetivo.',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: equiposMuted.withValues(alpha: 0.75),
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
                color: equipo.estado.colorTexto,
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
            color: equipo.estado.colorTexto,
          ),
        ),
      ],
    );
  }
}

// Leandro: Pie con horas realizadas/objetivo y acceso visual al detalle.
class _CardFooter extends StatelessWidget {
  final EquipoGlobalViewModel equipo;

  const _CardFooter({required this.equipo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${equipo.horasRealizadas.toStringAsFixed(1)} de ${equipo.horasObjetivo.toStringAsFixed(1)} hs',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: equiposInk,
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
        const Spacer(),
        const Text(
          'Ver detalle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: equiposBrand,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_rounded, size: 15, color: equiposBrand),
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

// Leandro: Traduce el EstadoEquipo calculado por el servicio a una insignia visual.
class _StatusBadge extends StatelessWidget {
  final EstadoEquipo status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.colorFondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.colorTexto,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.colorTexto,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
