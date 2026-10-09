import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_category_distribution.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:flutter/material.dart';

class AreaDetalleHeader extends StatelessWidget {
  final AreaGlobalViewModel area;
  final String periodo;

  const AreaDetalleHeader({
    super.key,
    required this.area,
    required this.periodo,
  });

  @override
  Widget build(BuildContext context) {
    final colaboradores = area.cantidadIntegrantes;
    final equipos = area.equiposGenerales.length;

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
              area.nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: areasInk,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$colaboradores ${colaboradores == 1 ? 'colaborador' : 'colaboradores'}'
              ' · $equipos ${equipos == 1 ? 'equipo general' : 'equipos generales'}',
              style: const TextStyle(fontSize: 14, color: areasMuted),
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
                border: Border.all(color: areasBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: areasMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    periodo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: areasInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: area.semaforo.colorFondo,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                area.semaforo.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: area.semaforo.colorTexto,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AreaDetalleResumen extends StatelessWidget {
  final AreaGlobalViewModel area;
  final bool esAnual;

  const AreaDetalleResumen({
    super.key,
    required this.area,
    this.esAnual = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final distribucion = AreasCategoryDistribution(
          horasNegocio: area.horasNegocio,
          horasBlandas: area.horasBlandas,
          horasLibres: area.horasLibres,
          horasDictado: area.horasDictado,
          esAnual: esAnual,
        );
        final avance = _AreaProgressPanel(area: area, esAnual: esAnual);

        if (constraints.maxWidth < 1050) {
          return Column(
            children: [distribucion, const SizedBox(height: 16), avance],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: distribucion),
              const SizedBox(width: 16),
              Expanded(child: avance),
            ],
          ),
        );
      },
    );
  }
}

class _AreaProgressPanel extends StatelessWidget {
  final AreaGlobalViewModel area;
  final bool esAnual;

  const _AreaProgressPanel({required this.area, required this.esAnual});

  @override
  Widget build(BuildContext context) {
    final progress = (area.porcentajeCumplimiento / 100).clamp(0.0, 1.0);
    final promedio = area.cantidadIntegrantes == 0
        ? 0.0
        : area.horasRealizadas / area.cantidadIntegrantes;
    final enObjetivo = _MetricRow(
      label: 'Integrantes en objetivo',
      value: '${area.integrantesEnObjetivo} de ${area.cantidadIntegrantes}',
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: areasPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avance del área',
            style: TextStyle(fontWeight: FontWeight.w700, color: areasInk),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${area.porcentajeCumplimiento.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: area.semaforo.colorTexto,
                ),
              ),
              Text(
                '${area.horasRealizadas.toStringAsFixed(1)} de ${area.horasObjetivo.toStringAsFixed(1)} h',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: areasMuted,
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
              color: area.semaforo.colorTexto,
            ),
          ),
          const SizedBox(height: 20),
          if (esAnual)
            Tooltip(
              message:
                  'Colaboradores que tuvieron objetivo en esta área durante al menos uno de los meses con datos del año.',
              child: enObjetivo,
            )
          else
            enObjetivo,
          const Divider(height: 22),
          _MetricRow(
            label: 'Promedio por integrante',
            value: '${promedio.toStringAsFixed(1)} h',
          ),
          const Divider(height: 22),
          _MetricRow(
            label: 'Desvío de horas',
            value: area.desvioHoras >= 0
                ? '+${area.desvioHoras.toStringAsFixed(1)} h'
                : '-${area.desvioHoras.abs().toStringAsFixed(1)} h',
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
            style: const TextStyle(fontSize: 13, color: areasMuted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: areasInk,
          ),
        ),
      ],
    );
  }
}
