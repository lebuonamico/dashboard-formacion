import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardCategoryHours extends StatelessWidget {
  final AsyncValue<List<CumplimientoEmpleado>> cumplimientosAsync;

  const DashboardCategoryHours({super.key, required this.cumplimientosAsync});

  @override
  Widget build(BuildContext context) {
    return cumplimientosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Error: $error'),
      data: (cumplimientos) {
        if (cumplimientos.isEmpty) return const SizedBox.shrink();

        final resumen = {
          for (final tipo in TipoCurso.values)
            tipo: _CategoryHoursSummary(
              // Sólo lo que suma al objetivo, igual que "Horas realizadas"
              // de Equipos y Áreas.
              completed: cumplimientos.fold<double>(
                0,
                (total, item) => total + item.horasAplicablesAlObjetivo(tipo),
              ),
              expected: cumplimientos.fold<double>(
                0,
                (total, item) => total + (item.horasRequeridas[tipo] ?? 0),
              ),
            ),
        };

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: context.panel(sombra: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¿En qué se están usando las horas?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Distribución por categorías prioritarias de aprendizaje.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Referencia sobre las horas esperadas',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 700 ? 2 : 1;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 82,
                    ),
                    itemCount: TipoCurso.values.length,
                    itemBuilder: (context, index) {
                      final tipo = TipoCurso.values[index];
                      return _CategoryHoursCard(
                        tipo: tipo,
                        summary: resumen[tipo]!,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryHoursSummary {
  final double completed;
  final double expected;

  const _CategoryHoursSummary({
    required this.completed,
    required this.expected,
  });

  double get progress =>
      expected == 0 ? 1 : (completed / expected).clamp(0.0, 1.0);

  bool get meetsTarget => expected == 0 || completed >= expected;
}

class _CategoryHoursCard extends StatelessWidget {
  final TipoCurso tipo;
  final _CategoryHoursSummary summary;

  const _CategoryHoursCard({required this.tipo, required this.summary});

  @override
  Widget build(BuildContext context) {
    final color = summary.meetsTarget
        ? context.colores.exito.texto
        : context.colores.advertencia.texto;
    final background = summary.meetsTarget
        ? context.colores.exito.fondo
        : context.colores.advertencia.fondo;
    final difference = summary.expected - summary.completed;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: context.panel().copyWith(
        color: context.colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tipo.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  summary.meetsTarget
                      ? 'Cumple'
                      : difference > 0
                      ? 'Faltan ${difference.toStringAsFixed(1)} h'
                      : 'En curso',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  text: '${summary.completed.toStringAsFixed(1)} h',
                  style: TextStyle(
                    color: context.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: ' alcanzadas',
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Esperadas: ${summary.expected.toStringAsFixed(1)} h',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 6,
              backgroundColor: context.colores.graficoPista,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
