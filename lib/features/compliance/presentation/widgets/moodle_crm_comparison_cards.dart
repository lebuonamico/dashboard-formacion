import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/moodle_crm_comparison.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';

/// Dos cards lado a lado: Moodle vs CRM en las categorías comparables
/// (Negocio y Blandas) y el total de cada fuente, con el desglose por
/// categoría de cada número.
class MoodleCrmComparisonCards extends StatelessWidget {
  final List<EmployeeCompliance> complianceList;

  const MoodleCrmComparisonCards({super.key, required this.complianceList});

  @override
  Widget build(BuildContext context) {
    final comparison = MoodleCrmComparison.from(complianceList);
    final comparables = _ComparisonCard(
      key: const Key('comparacion_comparables'),
      comparison: comparison,
    );
    final total = _CardTotalCrm(
      key: const Key('comparacion_total'),
      comparison: comparison,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [comparables, const SizedBox(height: 16), total],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: comparables),
              const SizedBox(width: 16),
              Expanded(child: total),
            ],
          ),
        );
      },
    );
  }
}

/// Moodle vs CRM en Negocio y Blandas, con columnas agrupadas por categoría.
class _ComparisonCard extends StatelessWidget {
  final MoodleCrmComparison comparison;

  const _ComparisonCard({super.key, required this.comparison});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colorMoodle = cs.primary;
    final colorCrm = context.colors.cyanAccent;
    const types = MoodleCrmComparison.comparables;
    final moodle = comparison.totalMoodle(types);
    final crm = comparison.totalCrm(types);

    return _Panel(
      title: 'Moodle vs CRM · Comparables',
      subtitle:
          'Negocio y Blandas, las categorías que existen en las dos fuentes',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _Total(
                source: 'MOODLE (LMS)',
                hours: moodle,
                color: colorMoodle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'vs',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: _Total(
                source: 'CRM',
                hours: crm,
                color: colorCrm,
                alignRight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _differenceText(),
          style: context.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: cs.outlineVariant),
        const SizedBox(height: 10),
        _ColumnsChart(
          types: types,
          comparison: comparison,
          colorMoodle: colorMoodle,
          colorCrm: colorCrm,
        ),
      ],
    );
  }

  String _differenceText() {
    if (comparison.match) return 'Las dos fuentes coinciden.';
    final difference = comparison.differenceComparable;
    final percentage = switch (comparison.percentageDifference) {
      final p? => ' (${p > 0 ? '+' : ''}${p.toStringAsFixed(0)}%)',
      null => '',
    };
    return 'CRM registra ${difference.abs().toStringAsFixed(1)} h '
        '${difference > 0 ? 'más' : 'menos'} que Moodle$percentage';
  }
}

class _Total extends StatelessWidget {
  final String source;
  final double hours;
  final Color color;
  final bool alignRight;

  const _Total({
    required this.source,
    required this.hours,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          source,
          style: context.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${hours.toStringAsFixed(1)} h',
          style: context.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Contenedor de las cards de la comparación: título, subtítulo y contenido.
class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: context.panel(shadow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Total de horas CRM y cómo se reparten entre las cuatro categorías.
class _CardTotalCrm extends StatelessWidget {
  final MoodleCrmComparison comparison;

  const _CardTotalCrm({super.key, required this.comparison});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colorCrm = context.colors.cyanAccent;
    final total = comparison.totalCrm(CourseCategory.values);

    return _Panel(
      title: 'Horas CRM · Total',
      subtitle: 'Todas las horas declaradas en CRM, por categoría',
      children: [
        _Total(source: 'CRM', hours: total, color: colorCrm),
        // Misma altura que la línea de diferencia de la otra card, para que
        // los divisores queden alineados.
        const SizedBox(height: 8),
        Text(
          'Repartidas entre las 4 categorías del plan',
          style: context.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: cs.outlineVariant),
        const SizedBox(height: 10),
        _ChartCrm(crm: comparison.crm, total: total),
      ],
    );
  }
}

/// Una columna por categoría del CRM, con su color y en una escala común a
/// las cuatro: horas arriba, nombre y parte del total abajo.
class _ChartCrm extends StatelessWidget {
  final Map<CourseCategory, double> crm;
  final double total;

  const _ChartCrm({required this.crm, required this.total});

  @override
  Widget build(BuildContext context) {
    final maximum = CourseCategory.values
        .map((type) => crm[type] ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final type in CourseCategory.values)
            Expanded(
              child: _Column(
                key: Key('comparacion_${type.name}'),
                hours: crm[type] ?? 0,
                maximum: maximum,
                height: _ColumnsChart._maximumHeight,
                color: context.colors.category(type).text,
                source:
                    '${type.shortLabel}\n'
                    '${(total == 0 ? 0 : (crm[type] ?? 0) / total * 100).toStringAsFixed(0)}%',
              ),
            ),
        ],
      ),
    );
  }
}

/// Columnas agrupadas: un grupo por categoría, con la columna de Moodle y la
/// de CRM en la misma escala, separados por una línea vertical.
class _ColumnsChart extends StatelessWidget {
  final List<CourseCategory> types;
  final MoodleCrmComparison comparison;
  final Color colorMoodle;
  final Color colorCrm;

  const _ColumnsChart({
    required this.types,
    required this.comparison,
    required this.colorMoodle,
    required this.colorCrm,
  });

  static const _maximumHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final maximum = [
      for (final type in types) ...[
        comparison.moodle[type] ?? 0,
        comparison.crm[type] ?? 0,
      ],
    ].fold<double>(0, (a, b) => a > b ? a : b);

    Widget group(CourseCategory type) => Expanded(
      key: Key('comparacion_${type.name}'),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Column(
                hours: comparison.moodle[type] ?? 0,
                maximum: maximum,
                height: _maximumHeight,
                color: colorMoodle,
                source: 'Moodle',
              ),
              const SizedBox(width: 16),
              _Column(
                hours: comparison.crm[type] ?? 0,
                maximum: maximum,
                height: _maximumHeight,
                color: colorCrm,
                source: 'CRM',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.colors.category(type).text,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < types.length; i++) ...[
              if (i > 0) VerticalDivider(width: 24, color: cs.outlineVariant),
              group(types[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una columna con las horas arriba y la fuente abajo.
class _Column extends StatelessWidget {
  final double hours;
  final double maximum;
  final double height;
  final Color color;
  final String source;

  const _Column({
    super.key,
    required this.hours,
    required this.maximum,
    required this.height,
    required this.color,
    required this.source,
  });

  static const _width = 64.0;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final barHeight = maximum == 0
        ? 0.0
        : height * (hours / maximum).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Alto fijo para que todas las columnas apoyen en la misma base; las
        // horas van justo encima de cada columna.
        SizedBox(
          height: height + 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${hours.toStringAsFixed(0)} h',
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: _width,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          source,
          textAlign: TextAlign.center,
          style: context.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
