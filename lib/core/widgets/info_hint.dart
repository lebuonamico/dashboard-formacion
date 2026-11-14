import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Help icon. Its text shows on hover and also on tap, so it can be read on
/// touch screens, where there is no hover.
class InfoHint extends StatelessWidget {
  final String message;
  final double size;

  /// By default, the faint text color.
  final Color? color;

  const InfoHint({
    super.key,
    required this.message,
    this.size = 15,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.tap,
    showDuration: const Duration(seconds: 8),
    constraints: const BoxConstraints(maxWidth: 320),
    child: Icon(
      Icons.info_outline,
      size: size,
      color: color ?? context.colors.faintText,
    ),
  );
}
