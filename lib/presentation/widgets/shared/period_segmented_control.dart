import 'package:app_finnegans/presentation/widgets/shared/filter_dropdown.dart';
import 'package:flutter/material.dart';

class PeriodSegmentedControl<T> extends StatelessWidget {
  final T selected;
  final List<T> options;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedForegroundColor;
  final Color unselectedForegroundColor;

  const PeriodSegmentedControl({
    super.key,
    required this.selected,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
    required this.selectedColor,
    required this.unselectedColor,
    required this.selectedForegroundColor,
    required this.unselectedForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: FilterDropdown<T>(
        value: selected,
        hint: 'Período',
        icon: Icons.date_range,
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(labelBuilder(option))),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
