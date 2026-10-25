import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';
import 'package:flutter/material.dart';

/// Indicadores de todas las áreas, con las mismas cards que el inicio.
class AreasKpiSection extends StatelessWidget {
  final int totalAreas;
  final int totalColaboradores;
  final double horasRealizadas;
  final double horasObjetivo;
  final double desvioHoras;
  final double cumplimientoGlobal;
  final bool esAnual;
  final int anio;
  final int mes;

  /// Variación del cumplimiento contra el mes anterior.
  final VariacionCumplimiento? variacion;

  /// Proyección a fin de año de todas las áreas; sin ella no se muestra la
  /// card.
  final ProyeccionAnual? proyeccion;

  const AreasKpiSection({
    super.key,
    required this.totalAreas,
    required this.totalColaboradores,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.desvioHoras,
    required this.cumplimientoGlobal,
    required this.anio,
    required this.mes,
    this.esAnual = false,
    this.variacion,
    this.proyeccion,
  });

  @override
  Widget build(BuildContext context) {
    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'ÁREAS ACTIVAS',
          value: '$totalAreas',
          suffix: 'en seguimiento',
          progress: 1,
          progressLabel: 'Con colaboradores elegibles',
          footer: '',
          icon: Icons.apartment_outlined,
          color: context.colorScheme.primary,
        ),
        DashboardKpiCard(
          title: 'COLABORADORES',
          value: '$totalColaboradores',
          suffix: 'en todas las áreas',
          progress: 1,
          progressLabel: 'Nómina elegible',
          footer: '',
          icon: Icons.people_outline,
          color: context.colores.acentoCian,
        ),
        horasValidasKpiCard(
          context,
          esAnual: esAnual,
          anio: anio,
          mes: mes,
          horas: horasRealizadas,
          objetivo: horasObjetivo,
        ),
        cumplimientoKpiCard(
          context,
          esAnual: esAnual,
          anio: anio,
          mes: mes,
          porcentaje: cumplimientoGlobal,
          variacion: variacion,
        ),
        if (proyeccion case final proyeccion?)
          proyeccionKpiCard(context, proyeccion),
      ],
    );
  }
}

/// Horas válidas para el objetivo contra la meta del período, como en el
/// inicio.
Widget horasValidasKpiCard(
  BuildContext context, {
  required bool esAnual,
  required int anio,
  required int mes,
  required double horas,
  required double objetivo,
}) {
  final periodo = esAnual
      ? 'AÑO $anio'
      : '${nombreMes(mes).toUpperCase()} $anio';
  final falta = objetivo - horas;
  return DashboardKpiCard(
    title: 'HORAS VÁLIDAS · $periodo',
    value: '${horas.toStringAsFixed(1)} h',
    suffix: 'para el objetivo',
    progress: objetivo == 0 ? 0 : (horas / objetivo).clamp(0.0, 1.0),
    progressLabel: 'Meta: ${objetivo.toStringAsFixed(0)} h',
    footer: falta > 0
        ? '${falta.toStringAsFixed(1)} h para la meta'
        : 'Meta alcanzada',
    icon: Icons.schedule_outlined,
    color: context.colorScheme.primary,
  );
}
