import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Small rectangular label with the text and background of a [ColorPair]:
/// the base of the seniority, course type and status chips.
class ColorLabel extends StatelessWidget {
  final String text;
  final ColorPair colors;
  final IconData? icon;

  const ColorLabel({
    super.key,
    required this.text,
    required this.colors,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: colors.text),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelMedium?.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
