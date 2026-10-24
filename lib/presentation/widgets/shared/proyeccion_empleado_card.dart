import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';
import 'package:flutter/material.dart';

/// Proyección a fin de año de un colaborador: si llega con su tendencia y,
/// si no, cuántas horas le faltan en cada habilidad de su plan.
class ProyeccionEmpleadoCard extends StatelessWidget {
  final ProyeccionEmpleado proyeccion;
  final int anio;

  const ProyeccionEmpleadoCard({
    super.key,
    required this.proyeccion,
    required this.anio,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colores = proyeccion.estado.colores(context);
    final cerrado = proyeccion.mesesRestantes == 0;
    final faltantes = proyeccion.faltantes;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formatearPorcentaje(proyeccion.porcentaje),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (proyeccion.variacion case final variacion?) ...[
                const SizedBox(width: 8),
                badgeVariacion(context, variacion, 'pts'),
              ],
              const Spacer(),
              Container(
                key: const Key('proyeccion_empleado_estado'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colores.fondo,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  proyeccion.estado.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colores.texto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${proyeccion.proyeccion.toStringAsFixed(0)} / '
            '${proyeccion.meta.toStringAsFixed(0)} h proyectadas a diciembre',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Corte: ${nombreMes(proyeccion.mesCorte)} $anio · tendencia de sus '
            'horas en los meses con datos',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (faltantes.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: context.colores.exito.texto,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cerrado
                        ? 'Cumplió todas las habilidades de su plan.'
                        : 'Con su tendencia cumple todas las habilidades de su plan.',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              cerrado
                  ? 'No llegó a cumplir:'
                  : 'Para llegar a diciembre tiene que reforzar:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            for (final categoria in faltantes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: context.colores.peligro.texto,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${categoria.tipo.label} · '
                        '${cerrado ? 'faltaron' : 'faltan'} '
                        '${categoria.falta.toStringAsFixed(1)} h'
                        '${cerrado ? '' : ' (+${(categoria.falta / proyeccion.mesesRestantes).toStringAsFixed(1)} h/mes)'}',
                        key: Key('proyeccion_falta_${categoria.tipo.name}'),
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              for (final categoria in proyeccion.categorias)
                Text(
                  '${categoria.tipo.label}: '
                  '${categoria.acumulado.toStringAsFixed(1)} / '
                  '${categoria.meta.toStringAsFixed(0)} h · proyecta '
                  '${categoria.proyectado.toStringAsFixed(1)} h '
                  '${categoria.llega ? '✓' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: categoria.llega
                        ? context.colores.exito.texto
                        : cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
