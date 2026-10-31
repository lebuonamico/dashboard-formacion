import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SummaryInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  /// Shows the full text on hover when it can be cut by the ellipsis.
  final bool withTooltip;

  const SummaryInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.withTooltip = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );

    return Row(
      children: [
        Icon(icon, size: 16, color: context.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: withTooltip ? Tooltip(message: text, child: label) : label,
        ),
      ],
    );
  }
}
