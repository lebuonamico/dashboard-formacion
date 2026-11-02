import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SummaryProgress extends StatelessWidget {
  final String caption;
  final double percentage;
  final ColorPair colors;
  final String? help;

  const SummaryProgress({
    super.key,
    required this.caption,
    required this.percentage,
    required this.colors,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    final help = this.help;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (help != null) ...[
                    const SizedBox(width: 5),
                    Tooltip(
                      message: help,
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: context.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPercentage(percentage),
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: context.colors.chartTrack,
            color: colors.text,
          ),
        ),
      ],
    );
  }
}
