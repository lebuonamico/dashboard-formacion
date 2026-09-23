import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Selector de período global de la pantalla.
/// Leandro: Está separado de los filtros del listado porque cambia todos los cálculos.
class EquiposPeriodControls extends StatelessWidget {
  final AlcancePeriodoEquipos alcance;
  final int selectedMonth;
  final int selectedYear;
  final List<int> availableYears;
  final ValueChanged<AlcancePeriodoEquipos?> onScopeChanged;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onYearChanged;

  const EquiposPeriodControls({
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
    // Leandro: Aseguramos que el año seleccionado siempre exista en el combo,
    // Leandro: aunque todavía no haya cargas CRM para ese año.
    final yearOptions = {...availableYears, selectedYear}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: equiposPanelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = _PeriodTitle();
          final scopeControl = _ScopeControl(
            alcance: alcance,
            onScopeChanged: onScopeChanged,
          );
          final monthField = _MonthField(
            selectedMonth: selectedMonth,
            enabled: alcance == AlcancePeriodoEquipos.mensual,
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
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Período de análisis',
          style: TextStyle(fontWeight: FontWeight.w700, color: equiposInk),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message:
              'Este período recalcula todos los indicadores de abajo. Las horas salen de CRM; equipos y colaboradores salen de la nómina cargada.',
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: equiposMuted.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _ScopeControl extends StatelessWidget {
  final AlcancePeriodoEquipos alcance;
  final ValueChanged<AlcancePeriodoEquipos?> onScopeChanged;

  const _ScopeControl({required this.alcance, required this.onScopeChanged});

  @override
  Widget build(BuildContext context) {
    // Leandro: SegmentedButton deja claro si el análisis es mensual o anual.
    return SegmentedButton<AlcancePeriodoEquipos>(
      segments: AlcancePeriodoEquipos.values
          .map(
            (scope) => ButtonSegment<AlcancePeriodoEquipos>(
              value: scope,
              label: Text(scope.label),
            ),
          )
          .toList(),
      selected: {alcance},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        onScopeChanged(selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : equiposInk;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? equiposBrand
              : Colors.white;
        }),
      ),
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
    // Leandro: En modo anual el mes queda deshabilitado porque el corte es todo el año.
    return DropdownButtonFormField<int>(
      initialValue: selectedMonth,
      isExpanded: true,
      decoration: _periodInputDecoration('Mes', Icons.calendar_month_outlined),
      items: List.generate(12, (index) => index + 1)
          .map(
            (month) => DropdownMenuItem<int>(
              value: month,
              child: Text(_monthLabel(month), overflow: TextOverflow.ellipsis),
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
      decoration: _periodInputDecoration('Año', Icons.event_outlined),
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

InputDecoration _periodInputDecoration(String hint, IconData icon) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: equiposBorder),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: equiposMuted),
    prefixIcon: Icon(icon, size: 19, color: equiposMuted),
    prefixIconConstraints: const BoxConstraints(minWidth: 42),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: equiposBrand, width: 1.5),
    ),
  );
}

String _monthLabel(int month) {
  const labels = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  return labels[month - 1];
}
