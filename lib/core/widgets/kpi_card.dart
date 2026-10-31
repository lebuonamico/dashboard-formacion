import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/area_compliance_providers.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/widgets/status_colors.dart';
import 'package:flutter/material.dart';

/// Fila de cards de indicadores, la misma en Inicio, Áreas, Equipos y sus
/// detalles: 5 columnas en pantallas anchas, 3 + 2, 2 o 1 en las más chicas.
class KpiCardRow extends StatelessWidget {
  final List<Widget> cards;

  const KpiCardRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1300
            ? 5
            : width >= 1050
            // Con 5 cards, 3 + 2 queda mejor que 4 + 1.
            ? (cards.length == 5 ? 3 : 4)
            : width >= 680
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 156,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

/// Card de cumplimiento con el criterio del inicio. En el anual, el acumulado
/// del año y cuántos puntos subió o bajó contra el mes anterior; en el
/// mensual, el del mes y la variación de horas por persona contra el anterior.
/// [color] reemplaza al del semáforo cuando la sección tiene su propio estado.
Widget complianceKpiCard(
  BuildContext context, {
  required bool isAnnual,
  required int year,
  required int month,
  required double percentage,
  ComplianceVariation? variation,
  Color? color,
}) {
  final colorCard =
      color ?? ComplianceLevel.fromPercentage(percentage).colors(context).text;
  if (isAnnual) {
    return DashboardKpiCard(
      title: 'CUMPLIMIENTO · AÑO $year',
      value: formatPercentage(percentage),
      suffix: 'acumulado del año',
      suffixBelow: true,
      progress: (percentage / 100).clamp(0.0, 1.0),
      progressLabel: 'Acumulado del año',
      footer: '',
      badge: variation?.points == null
          ? null
          : variationBadge(
              context,
              variation!.points!,
              'pts',
              key: const Key('kpi_variacion_mes'),
            ),
      icon: Icons.event_available_outlined,
      color: colorCard,
      help:
          'Horas válidas acumuladas en el año sobre la suma de los objetivos '
          'de los meses con datos. Los meses sin registros CRM ni LMS no '
          'cuentan. El recuadro muestra cuántos puntos cambió contra el '
          'acumulado hasta el mes anterior.',
    );
  }

  final previous = variation?.previousHoursPerPerson;
  return DashboardKpiCard(
    title: 'CUMPLIMIENTO · ${monthName(month).toUpperCase()}',
    value: formatPercentage(percentage),
    suffix: 'del objetivo del mes',
    progress: (percentage / 100).clamp(0.0, 1.0),
    progressLabel: variation == null
        ? ''
        : '${variation.hoursPerPerson.toStringAsFixed(1)} h por persona',
    footer: previous == null
        ? 'Sin datos del mes anterior'
        : 'Mes anterior: ${previous.toStringAsFixed(1)} h',
    badge: variation?.hours == null
        ? null
        : variationBadge(
            context,
            variation!.hours!,
            'h',
            key: const Key('kpi_variacion_mes'),
          ),
    icon: Icons.event_available_outlined,
    color: colorCard,
    help:
        'Horas válidas del mes sobre el objetivo del mes de los colaboradores '
        'elegibles, según su seniority. Cada persona suma como máximo su '
        'objetivo en cada categoría. El recuadro compara las horas por '
        'persona con el mes anterior.',
  );
}

/// Card de proyección a fin de año con el criterio del inicio: porcentaje de
/// la meta, variación contra el mes anterior, horas por persona, estado,
/// cuántos llegan y el ajuste necesario.
Widget projectionKpiCard(BuildContext context, AnnualProjection projection) {
  final colors = projection.status.colors(context);
  final goal = projection.goal;
  final closed = projection.remainingMonths == 0;

  return DashboardKpiCard(
    title: 'PROYECCIÓN ANUAL',
    value: formatPercentage(projection.percentage),
    suffix:
        '${projection.projection.toStringAsFixed(0)} / '
        '${goal.toStringAsFixed(0)} h por persona',
    suffixBelow: true,
    progress: goal == 0 ? 1 : (projection.projection / goal).clamp(0.0, 1.0),
    progressLabel:
        '${projection.status.label} · ${projection.arrive} de '
        '${projection.employeeCount} ${closed ? 'cumplieron' : 'llegan'}',
    footer: closed
        ? 'Año cerrado: ${formatPercentage(projection.percentage)} de la meta'
        : projection.adjustment > 0
        ? 'Ajuste: +${projection.adjustment.toStringAsFixed(1)} h/mes por persona'
        : 'En camino a la meta',
    badge: projection.projectionVariation == null
        ? null
        : variationBadge(
            context,
            projection.projectionVariation!,
            'pts',
            key: const Key('kpi_variacion_proyeccion'),
          ),
    icon: switch (projection.status) {
      ProjectionStatus.onTrack => Icons.trending_up,
      ProjectionStatus.reachable => Icons.trending_flat,
      ProjectionStatus.atRisk => Icons.trending_down,
    },
    color: colors.text,
    help:
        'Estimación a diciembre: lo acumulado más la tendencia de cada '
        'colaborador según sus meses con datos, sobre la meta del año. Las '
        'horas de una persona no cubren a otra, ni las de una categoría a '
        'otra. En camino: 100 % o más; Alcanzable: desde 85 %; En riesgo: '
        'menos de 85 %. El ajuste son las horas por persona y por mes que '
        'faltan para llegar.',
  );
}

/// "▲ +2.3 pts vs mes anterior" en verde, o "▼ -1.0 pts …" en rojo.
Widget variationBadge(
  BuildContext context,
  double value,
  String unit, {
  Key? key,
}) {
  final improved = value >= 0;
  return DashboardKpiBadge(
    key: key,
    text:
        '${improved ? '▲ +' : '▼ '}${value.toStringAsFixed(1)} $unit '
        'vs mes anterior',
    colors: improved ? context.colors.success : context.colors.danger,
  );
}

/// Recuadro chico dentro de una card: estado o variación.
class DashboardKpiBadge extends StatelessWidget {
  final String text;
  final ColorPair colors;

  const DashboardKpiBadge({
    super.key,
    required this.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
      ),
    );
  }
}

class DashboardKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String suffix;
  final double progress;
  final String progressLabel;
  final String footer;
  final String? secondaryText;

  /// Recuadro chico al lado del valor (por ejemplo, la variación del mes).
  final Widget? badge;

  /// Muestra el texto gris debajo del valor en lugar de al lado, para cuando
  /// no entra junto al recuadro.
  final bool suffixBelow;
  final IconData icon;
  final Color color;

  /// Qué muestra la card y cómo se calcula. Aparece al pasar el mouse o
  /// tocar el ícono de información junto al título.
  final String? help;

  const DashboardKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.suffix,
    required this.progress,
    required this.progressLabel,
    required this.footer,
    this.secondaryText,
    this.badge,
    this.suffixBelow = false,
    required this.icon,
    required this.color,
    this.help,
  });

  Widget _textSuffix(BuildContext context) => Text(
    suffix,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.textTheme.labelSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: context.panel(shadow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (help case final help?) ...[
                Tooltip(
                  message: help,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 8),
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: context.colors.faintText,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(icon, size: 18, color: color),
            ],
          ),
          if (secondaryText != null) ...[
            const SizedBox(height: 3),
            Text(
              secondaryText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.success.text,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: context.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              if (suffixBelow)
                const Spacer()
              else
                Flexible(child: _textSuffix(context)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Flexible(child: badge!),
              ],
            ],
          ),
          if (suffixBelow) ...[const SizedBox(height: 2), _textSuffix(context)],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.colors.chartTrack,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Quiénes cuentan en el período, para las cards de colaboradores.
const eligiblePayrollHelp =
    'Colaboradores de la nómina elegibles en el período: ya habían ingresado '
    'y estaban activos al cierre del mes (en el anual, en algún mes con '
    'datos).';

const monthCreditedHoursHelp =
    'Horas que cuentan para el objetivo del mes: cursos de Negocio y Blandas '
    'finalizados en el LMS, con la carga horaria del catálogo, y horas de '
    'Libres y Dictado cargadas en el CRM. Cada persona suma como máximo su '
    'objetivo en cada categoría.';

const annualCreditedHoursHelp =
    'Suma de las horas válidas de los meses con datos del año: cursos de '
    'Negocio y Blandas finalizados en el LMS y horas de Libres y Dictado del '
    'CRM. Un mes fuerte compensa uno flojo; cada persona suma como máximo su '
    'objetivo anual en cada categoría.';

/// Integrantes de un área o equipo y cuántos cumplieron.
String membersHelp(String section) =>
    'Colaboradores elegibles $section en el período. Abajo, cuántos '
    'cumplieron el objetivo en todas sus categorías.';

/// Objetivo de horas de un área o equipo.
String targetHelp(String section) =>
    'Horas que $section debía hacer según el plan de formación para la '
    'seniority de cada integrante. En el anual, la suma de los objetivos de '
    'los meses con datos.';
