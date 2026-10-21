import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/period_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/period_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_dropdown.dart';

class AreasPeriodControls extends StatelessWidget {
  final AlcancePeriodo alcance;
  final int selectedMonth;
  final int selectedYear;
  final List<int> availableYears;
  final ValueChanged<AlcancePeriodo> onScopeChanged;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onYearChanged;

  const AreasPeriodControls({
    super.key,
    required this.alcance,
    required this.selectedMonth,
    required this.selectedYear,
    required this.availableYears,
    required this.onScopeChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final yearOptions = {...availableYears, selectedYear}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.panel(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = _PeriodTitle(esAnual: alcance == AlcancePeriodo.anual);
          final scopeControl = PeriodoSegmentedControl<AlcancePeriodo>(
            selected: alcance,
            options: AlcancePeriodo.values,
            labelBuilder: (scope) => scope.label,
            onChanged: onScopeChanged,
            selectedColor: context.colorScheme.primary,
            unselectedColor: context.colorScheme.surface,
            selectedForegroundColor: context.colorScheme.onPrimary,
            unselectedForegroundColor: context.colorScheme.onSurface,
          );
          final monthField = _MonthField(
            selectedMonth: selectedMonth,
            enabled: alcance == AlcancePeriodo.mensual,
            onChanged: onMonthChanged,
          );
          final yearField = _YearField(
            selectedYear: selectedYear,
            yearOptions: yearOptions,
            onChanged: onYearChanged,
          );

          if (constraints.maxWidth < 820) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 12),
                scopeControl,
                const SizedBox(height: 12),
                monthField,
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
              const SizedBox(width: 12),
              SizedBox(width: 170, child: monthField),
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
  final bool esAnual;

  const _PeriodTitle({this.esAnual = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Período de análisis',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: esAnual
              ? 'El anual suma únicamente los resultados mensuales de los meses con datos CRM o LMS. Los meses sin datos no suman horas ni objetivos.'
              : 'El período se evalúa si tiene registros CRM o LMS. Se incluyen todas las áreas con colaboradores elegibles al cierre, aunque tengan 0 horas. Si no hay registros, se muestra Sin datos.',
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _MonthField extends StatelessWidget {
  final int selectedMonth;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _MonthField({
    required this.selectedMonth,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: selectedMonth,
      isExpanded: true,
      decoration: filtroInputDecoration('Mes', Icons.calendar_month_outlined),
      items: List.generate(12, (index) => index + 1)
          .map(
            (month) => DropdownMenuItem<int>(
              value: month,
              child: Text(nombreMes(month), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _YearField extends StatelessWidget {
  final int selectedYear;
  final List<int> yearOptions;
  final ValueChanged<int?> onChanged;

  const _YearField({
    required this.selectedYear,
    required this.yearOptions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: selectedYear,
      isExpanded: true,
      decoration: filtroInputDecoration('Año', Icons.event_outlined),
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
