import 'package:flutter/material.dart';

class PeriodoSegmentedControl<T> extends StatelessWidget {
  final T selected;
  final List<T> options;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedForegroundColor;
  final Color unselectedForegroundColor;

  const PeriodoSegmentedControl({
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
    return SegmentedButton<T>(
      segments: options
          .map(
            (option) => ButtonSegment<T>(
              value: option,
              label: Text(labelBuilder(option)),
            ),
          )
          .toList(),
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        onChanged(selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? selectedForegroundColor
              : unselectedForegroundColor;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? selectedColor
              : unselectedColor;
        }),
      ),
    );
  }
}
