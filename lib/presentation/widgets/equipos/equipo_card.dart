import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Leandro: Tarjeta de un equipo. Recibe su ViewModel desde la grilla y muestra sus datos.
/// Leandro: Al tocarla, abre el detalle existente de equipo.dart usando el router.
class EquipoCard extends StatelessWidget {
  final EquipoGlobalViewModel equipo;

  const EquipoCard({super.key, required this.equipo});

  @override
  Widget build(BuildContext context) {
    // Leandro: La barra espera un valor entre 0 y 1: 75 % se convierte en 0.75.
    // Leandro: clamp limita sólo la barra al 100 %; el texto conserva el porcentaje real.
    final progress = (equipo.porcentajeCumplimiento / 100).clamp(0.0, 1.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // Leandro: InkWell detecta el toque en la tarjeta completa. push agrega el detalle
        // Leandro: a la navegación, permitiendo volver. Uri.encodeComponent codifica los
        // Leandro: nombres con espacios u otros caracteres para incluirlos en la dirección.
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
                  color: equipo.semaforo.colorTexto,
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
                      // Leandro: Spacer ocupa el hueco libre y alinea el progreso y el pie
                      // Leandro: en tarjetas cuyos nombres tienen distinta cantidad de líneas.
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

// Leandro: Nombre y área del equipo, junto al distintivo de estado.
// Leandro: maxLines y ellipsis acotan nombres largos dentro de la tarjeta.
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
        _StatusBadge(status: equipo.semaforo),
      ],
    );
  }
}

// Leandro: Recibe sólo el nombre del líder porque es el único dato que necesita mostrar.
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

// Leandro: Muestra dos medidas distintas: personas que cumplen su objetivo y cumplimiento
// Leandro: agregado de horas. El porcentaje y la barra representan esta segunda medida.
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
            Text(
              '${equipo.integrantesEnObjetivo} de ${equipo.cantidadIntegrantes} en objetivo',
              style: const TextStyle(fontSize: 12, color: equiposMuted),
            ),
            Text(
              '${equipo.porcentajeCumplimiento.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: equipo.semaforo.colorTexto,
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
            color: equipo.semaforo.colorTexto,
          ),
        ),
      ],
    );
  }
}

// Leandro: Horas realizadas/objetivo y texto de navegación. El toque lo maneja el InkWell
// Leandro: de la tarjeta completa; este texto no necesita un segundo onTap.
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
}

// Leandro: Usa etiqueta y colores del mismo EstadoSemaforo calculado en el provider.
// Leandro: Acompañar el color con texto permite entender el estado sin depender del color.
class _StatusBadge extends StatelessWidget {
  final EstadoSemaforo status;

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
