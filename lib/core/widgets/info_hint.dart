import 'package:app_finnegans/core/layout/window_size.dart';
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

  /// The tap area on touch screens, below the desktop width: as wide as a
  /// button, but not as tall, so the label rows it sits in (some in cards of
  /// fixed height) keep their height.
  static const touchTarget = Size(48, 32);

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.info_outline,
      size: size,
      color: color ?? context.colors.faintText,
    );
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 8),
      constraints: const BoxConstraints(maxWidth: 320),
      child: context.usesModalNavigation
          // The icon keeps its size; the transparent box takes the taps around it.
          ? ColoredBox(
              color: Colors.transparent,
              child: SizedBox.fromSize(
                size: touchTarget,
                child: Center(child: icon),
              ),
            )
          : icon,
    );
  }
}
