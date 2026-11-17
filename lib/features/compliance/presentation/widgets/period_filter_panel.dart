import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/core/period/presentation/period_segmented_control.dart';
import 'package:app_finnegans/core/widgets/info_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Period selector wired to the global providers: every screen that uses it
/// shares the same period.
class PeriodFilterPanel extends ConsumerWidget {
  /// Who the period's calculation includes, as a sentence of the monthly
  /// help text.
  final String included;

  /// Shown next to the title, like the print report button.
  final Widget? action;

  /// Narrower than this (a phone), the scope is a segmented control and the
  /// month and year share a row.
  static const compactWidth = 600.0;

  const PeriodFilterPanel({
    super.key,
    this.included =
        'Se incluyen todos los equipos con colaboradores elegibles al '
        'cierre, aunque tengan 0 horas.',
    this.action,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedScope = ref.watch(periodFilterProvider).scope;
    final month = ref.watch(periodFilterProvider).month;
    final year = ref.watch(periodFilterProvider).year;
    final availableYears = ref
        .watch(availableTeamYearsProvider)
        .maybeWhen(data: (years) => years, orElse: () => [year]);
    final yearOptions = {...availableYears, year}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.panel(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = _PeriodTitle(
            isAnnual: selectedScope == PeriodScope.annual,
            included: included,
            action: action,
          );
          final scopeControl = PeriodSegmentedControl<PeriodScope>(
            selected: selectedScope,
            options: PeriodScope.values,
            labelBuilder: (scope) => scope.label,
            onChanged: (value) =>
                ref.read(periodFilterProvider.notifier).setScope(value),
            selectedColor: context.colorScheme.primary,
            unselectedColor: context.colorScheme.surface,
            selectedForegroundColor: context.colorScheme.onPrimary,
            unselectedForegroundColor: context.colorScheme.onSurface,
          );
          // The annual scope covers the whole year: the month only applies to monthly.
          final isMonthly = selectedScope == PeriodScope.monthly;
          // On phones the fields go without their icon, so the value fits.
          final narrow = constraints.maxWidth < compactWidth;
          // A tablet: everything below the title in one row. A narrow desktop
          // window keeps the stacked layout.
          final singleRow =
              !narrow &&
              constraints.maxWidth < 820 &&
              context.windowSize != WindowSize.expanded;
          final showIcon = !narrow && !singleRow;
          final monthField = _MonthField(
            selectedMonth: month,
            showIcon: showIcon,
            onChanged: (value) {
              if (value == null) return;
              ref.read(periodFilterProvider.notifier).setMonth(value);
            },
          );
          final yearField = _YearField(
            selectedYear: year,
            yearOptions: yearOptions,
            showIcon: showIcon,
            onChanged: (value) {
              if (value == null) return;
              ref.read(periodFilterProvider.notifier).setYear(value);
            },
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 12),
                SegmentedButton<PeriodScope>(
                  key: const Key('period_scope_segments'),
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  segments: [
                    for (final scope in PeriodScope.values)
                      ButtonSegment(value: scope, label: Text(scope.label)),
                  ],
                  selected: {selectedScope},
                  onSelectionChanged: (value) => ref
                      .read(periodFilterProvider.notifier)
                      .setScope(value.first),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (isMonthly) ...[
                      Expanded(flex: 3, child: monthField),
                      const SizedBox(width: 12),
                    ],
                    Expanded(flex: 2, child: yearField),
                  ],
                ),
              ],
            );
          }
          if (singleRow) {
            return Column(
              key: const Key('period_single_row'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 12),
                Row(
                  children: [
                    scopeControl,
                    if (isMonthly) ...[
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: monthField),
                    ],
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: yearField),
                  ],
                ),
              ],
            );
          }
          if (constraints.maxWidth < 820) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 12),
                scopeControl,
                if (isMonthly) ...[const SizedBox(height: 12), monthField],
                const SizedBox(height: 12),
                yearField,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              scopeControl,
              if (isMonthly) ...[
                const SizedBox(width: 12),
                SizedBox(width: 170, child: monthField),
              ],
              const SizedBox(width: 12),
              SizedBox(width: 135, child: yearField),
            ],
          );
        },
      ),
    );
  }
}

class _PeriodTitle extends StatelessWidget {
  final bool isAnnual;
  final String included;
  final Widget? action;

  const _PeriodTitle({
    required this.isAnnual,
    required this.included,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            'Período de análisis',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 6),
        InfoHint(
          message: isAnnual
              ? 'El anual suma únicamente los resultados mensuales de los meses con datos CRM o LMS. Los meses sin datos no suman horas ni objetivos.'
              : 'El período se evalúa si tiene registros CRM o LMS. $included Si no hay registros, se muestra Sin datos.',
          size: 16,
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        if (action case final action?) ...[const SizedBox(width: 12), action],
      ],
    );
  }
}

class _MonthField extends StatelessWidget {
  final int selectedMonth;
  final bool showIcon;
  final ValueChanged<int?> onChanged;

  const _MonthField({
    required this.selectedMonth,
    required this.showIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterDropdown<int>(
      value: selectedMonth,
      hint: 'Mes',
      icon: Icons.calendar_month_outlined,
      showIcon: showIcon,
      items: List.generate(12, (index) => index + 1)
          .map(
            (month) => DropdownMenuItem<int>(
              value: month,
              child: Text(monthName(month), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _YearField extends StatelessWidget {
  final int selectedYear;
  final List<int> yearOptions;
  final bool showIcon;
  final ValueChanged<int?> onChanged;

  const _YearField({
    required this.selectedYear,
    required this.yearOptions,
    required this.showIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterDropdown<int>(
      value: selectedYear,
      hint: 'Año',
      icon: Icons.event_outlined,
      showIcon: showIcon,
      items: yearOptions
          .map(
            (year) => DropdownMenuItem<int>(
              value: year,
              child: Text('$year', overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
