import 'package:app_finnegans/core/theme/app_theme.dart';
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

/// "▲ +2.3 pts vs mes anterior" in green, or "▼ -1.0 pts …" in red.
class VariationBadge extends StatelessWidget {
  final double value;
  final String unit;

  const VariationBadge({super.key, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final improved = value >= 0;
    return DashboardKpiBadge(
      text:
          '${improved ? '▲ +' : '▼ '}${value.toStringAsFixed(1)} $unit '
          'vs mes anterior',
      colors: improved ? context.colors.success : context.colors.danger,
    );
  }
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
