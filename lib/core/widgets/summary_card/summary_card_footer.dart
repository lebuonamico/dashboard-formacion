import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SummaryCardFooter extends StatelessWidget {
  final double completedHours;
  final double targetHours;
  final String actionLabel;
  final double? deviation;

  const SummaryCardFooter({
    super.key,
    required this.completedHours,
    required this.targetHours,
    required this.actionLabel,
    this.deviation,
  });

  @override
  Widget build(BuildContext context) {
    final deviation = this.deviation;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '${completedHours.toStringAsFixed(1)} de ${targetHours.toStringAsFixed(1)} hs',
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ),
              if (deviation != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatHoursDeviation(deviation),
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: deviation >= 0
                        ? context.colors.success.text
                        : context.colors.danger.text,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          actionLabel,
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.arrow_forward_rounded,
          size: 15,
          color: context.colorScheme.primary,
        ),
      ],
    );
  }
}
