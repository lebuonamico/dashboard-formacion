import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Tappable card with a status-colored top strip: a header, detail rows, a
/// progress section pinned to the bottom and a footer.
class SummaryCard extends StatelessWidget {
  final ColorPair colors;
  final VoidCallback onTap;
  final Widget header;
  final List<Widget> details;
  final Widget progress;
  final Widget footer;

  const SummaryCard({
    super.key,
    required this.colors,
    required this.onTap,
    required this.header,
    this.details = const [],
    required this.progress,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: context.panel(shadow: true),
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: colors.text,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 13),
                      ...details,
                      const Spacer(),
                      progress,
                      const SizedBox(height: 9),
                      footer,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
