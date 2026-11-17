import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

/// Cards in rows of [columns], each row as tall as its tallest card: the
/// layout for narrow windows, where a fixed height either leaves room to spare
/// or cuts the text. The cards are measured with `IntrinsicHeight`, so they
/// cannot hold a `LayoutBuilder`; they may hold `Expanded` and `Spacer`.
class CardRows extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double spacing;

  const CardRows({
    super.key,
    required this.children,
    this.columns = 1,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, row) in children.slices(columns).indexed) ...[
        if (index > 0) SizedBox(height: spacing),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) SizedBox(width: spacing),
                Expanded(
                  child: column < row.length
                      ? row[column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}
