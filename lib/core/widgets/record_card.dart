import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A labelled value of a [RecordCard], such as "Área: Desarrollo".
class RecordMetric {
  final String label;
  final String value;

  const RecordMetric(this.label, this.value);
}

/// One row of a list, as a card: what a table row shows on wide screens. The
/// whole card is the tap target; with [onTap], a chevron says it opens.
class RecordCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;

  /// Beside the title: a status or a chip.
  final Widget? trailing;
  final List<RecordMetric> metrics;

  /// Below the metrics, across the card (for example, the category progress).
  final Widget? footer;
  final VoidCallback? onTap;

  const RecordCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.metrics = const [],
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final radius = BorderRadius.circular(8);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: context.panel(),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (leading case final leading?) ...[
                      leading,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          if (subtitle case final subtitle?)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (trailing case final trailing?) ...[
                      const SizedBox(width: 8),
                      trailing,
                    ],
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    ],
                  ],
                ),
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      for (final metric in metrics) _Metric(metric: metric),
                    ],
                  ),
                ],
                if (footer case final footer?) ...[
                  const SizedBox(height: 12),
                  footer,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final RecordMetric metric;

  const _Metric({required this.metric});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        metric.label,
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      Text(
        metric.value,
        style: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.intermediateText,
        ),
      ),
    ],
  );
}
