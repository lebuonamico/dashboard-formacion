import 'package:flutter/material.dart';

/// Two charts with the same height side by side; on narrow screens, stacked.
class SideBySideCharts extends StatelessWidget {
  static const _breakpoint = 1180.0;

  final Widget first;
  final Widget second;

  const SideBySideCharts({
    super.key,
    required this.first,
    required this.second,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _breakpoint) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}
