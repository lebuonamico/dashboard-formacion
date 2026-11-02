import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Back arrow. Instead of Material's ripple (a circle that appears and
/// vanishes at once), the feedback is continuous: a round background that fades
/// on hover, a slight nudge of the arrow and a small shrink on press.
class AppBackButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const AppBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Volver',
  });

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton> {
  static const _duration = Duration(milliseconds: 160);

  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final backgroundColor = _pressed
        ? cs.onSurface.withValues(alpha: 0.1)
        : _hover
        ? cs.onSurface.withValues(alpha: 0.06)
        : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOut,
          width: 40,
          height: 40,
          // Rounded square with a border: it reads as a "Volver" button and differs
          // from the menu's round blue toggle.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: backgroundColor,
            border: Border.all(color: cs.outline),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              // No ripple or highlight of its own: the background above is the feedback.
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              onTap: widget.onPressed,
              onHover: (hover) => setState(() => _hover = hover),
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              child: Center(
                child: AnimatedSlide(
                  offset: Offset(_hover ? -0.1 : 0, 0),
                  duration: _duration,
                  curve: Curves.easeOut,
                  child: Icon(Icons.arrow_back, size: 20, color: cs.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
