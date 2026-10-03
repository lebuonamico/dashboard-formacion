import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_category_distribution.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_status_style.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Encabezado del equipo con su período y estado calculado.
class EquipoDetalleHeader extends StatelessWidget {
  final EquipoGlobalViewModel equipo;
  final String periodo;

  const EquipoDetalleHeader({
    super.key,
    required this.equipo,
    required this.periodo,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              equipo.nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: equiposInk,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${equipo.area} · Líder: ${equipo.lider}',
              style: const TextStyle(fontSize: 14, color: equiposMuted),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: equiposBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: equiposMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    periodo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: equiposInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: equipo.estado.colorFondo,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                equipo.estado.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: equipo.estado.colorTexto,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Leandro: Alinea la distribución y el avance usando el mismo resumen calculado.
class EquipoDetalleResumen extends StatelessWidget {
  final EquipoGlobalViewModel equipo;

  const EquipoDetalleResumen({super.key, required this.equipo});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final distribucion = EquiposCategoryDistribution(
          horasNegocio: equipo.horasNegocio,
          horasBlandas: equipo.horasBlandas,
          horasLibres: equipo.horasLibres,
          horasDictado: equipo.horasDictado,
        );
        final avance = _TeamProgressPanel(equipo: equipo);

        if (constraints.maxWidth < 1050) {
          return Column(
            children: [distribucion, const SizedBox(height: 16), avance],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SizedBox(height: 260, child: distribucion)),
            const SizedBox(width: 16),
            Expanded(child: SizedBox(height: 260, child: avance)),
          ],
        );
      },
    );
  }
}

class _TeamProgressPanel extends StatelessWidget {
  final EquipoGlobalViewModel equipo;

  const _TeamProgressPanel({required this.equipo});

  @override
  Widget build(BuildContext context) {
    final progress = (equipo.porcentajeCumplimiento / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: equiposPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avance del equipo',
            style: TextStyle(fontWeight: FontWeight.w700, color: equiposInk),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${equipo.porcentajeCumplimiento.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: equipo.estado.colorTexto,
                ),
              ),
              Text(
                '${equipo.horasRealizadas.toStringAsFixed(1)} de ${equipo.horasObjetivo.toStringAsFixed(1)} h',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: equiposMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFEAECF0),
              color: equipo.estado.colorTexto,
            ),
          ),
          const SizedBox(height: 20),
          _MetricRow(
            label: 'Integrantes en objetivo',
            value:
                '${equipo.integrantesEnObjetivo} de ${equipo.cantidadIntegrantes}',
          ),
          const Divider(height: 22),
          _MetricRow(
            label: 'Promedio por integrante',
            value: '${equipo.promedioPorColaborador.toStringAsFixed(1)} h',
          ),
          const Divider(height: 22),
          _MetricRow(
            label: 'Desvío de horas',
            value: equipo.desvioHoras >= 0
                ? '+${equipo.desvioHoras.toStringAsFixed(1)} h'
                : '-${equipo.desvioHoras.abs().toStringAsFixed(1)} h',
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: equiposMuted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: equiposInk,
          ),
        ),
      ],
    );
  }
}
