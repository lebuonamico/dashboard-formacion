import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Row of KPI cards, the same on the home, areas and teams screens and
/// their details: 5 columns on wide screens, then 3 + 2, 2 or 1.
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
            // With 5 cards, 3 + 2 looks better than 4 + 1.
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
    // The sign follows the shown tenth, so -0.04 never reads "▼ -0,0".
    final tenths = (value * 10).round();
    final shown = formatDecimal(tenths.abs() / 10);
    return DashboardKpiBadge(
      text:
          '${switch (tenths.sign) {
            1 => '▲ +',
            -1 => '▼ -',
            _ => '= ',
          }}$shown $unit vs mes anterior',
      colors: switch (tenths.sign) {
        1 => context.colors.success,
        -1 => context.colors.danger,
        _ => context.colors.neutral,
      },
    );
  }
}

/// Small box inside a card: a status or a variation.
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

  /// Small box next to the value (for example, the month's variation).
  final Widget? badge;

  /// Shows the grey text below the value instead of beside it, for when it
  /// does not fit next to the badge.
  final bool suffixBelow;
  final IconData icon;
  final Color color;

  /// What the card shows and how it is calculated. Shown on hover or when
  /// tapping the info icon next to the title.
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
                Flexible(child: _Suffix(suffix)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Flexible(child: badge!),
              ],
            ],
          ),
          if (suffixBelow) ...[const SizedBox(height: 2), _Suffix(suffix)],
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

class _Suffix extends StatelessWidget {
  final String text;

  const _Suffix(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.textTheme.labelSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    ),
  );
}

/// Who counts in the period, for the employee cards.
const eligiblePayrollHelp =
    'Colaboradores de la nómina elegibles en el período: ya habían ingresado '
    'y estaban activos al cierre del mes (en el anual, en algún mes con '
    'datos).';

const monthCreditedHoursHelp =
    'Horas que cuentan para el objetivo del mes: cursos de Negocio y Blandas '
    'finalizados en el LMS, con la carga horaria del catálogo, y horas de '
    'Libres y Dictado declaradas en el CRM. Cada colaborador suma como máximo '
    'su objetivo en cada categoría.';

const annualCreditedHoursHelp =
    'Suma de las horas válidas de los meses con datos del año: cursos de '
    'Negocio y Blandas finalizados en el LMS y horas de Libres y Dictado del '
    'CRM. Un mes fuerte compensa uno flojo; cada colaborador suma como máximo '
    'su objetivo anual en cada categoría.';

/// Members of an area or team and how many met the target.
String membersHelp(String section) =>
    'Colaboradores elegibles $section en el período. Abajo, cuántos '
    'cumplieron el objetivo en todas sus categorías.';

String targetHelp(String section) =>
    'Horas que $section debía hacer según el plan de formación para la '
    'seniority de cada integrante. En el anual, la suma de los objetivos de '
    'los meses con datos.';
