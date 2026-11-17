import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_message.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_motion.dart';
import 'package:flutter/material.dart';

/// The round button that opens the assistant.
class AssistantLauncherButton extends StatefulWidget {
  static const symbolSize = 52.0;

  final VoidCallback onPressed;
  const AssistantLauncherButton({super.key, required this.onPressed});

  @override
  State<AssistantLauncherButton> createState() =>
      _AssistantLauncherButtonState();
}

class _AssistantLauncherButtonState extends State<AssistantLauncherButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final gradient = context.colors.aiSymbolGradient;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: assistantMotion(context, 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: .85 + .15 * value, child: child),
      ),
      child: AnimatedScale(
        scale: _hover || _focus ? 1.05 : 1,
        duration: assistantMotion(context, 160),
        child: AnimatedContainer(
          duration: assistantMotion(context, 160),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _focus ? cs.onSurface : cs.surface,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[1].withValues(
                  alpha: _hover || _focus ? .31 : .19,
                ),
                blurRadius: 26,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: gradient[0].withValues(alpha: .19),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Tooltip(
            message: 'Preguntale a la IA',
            child: SizedBox(
              width: AssistantLauncherButton.symbolSize,
              height: AssistantLauncherButton.symbolSize,
              child: Stack(
                children: [
                  const AssistantSymbol(
                    size: AssistantLauncherButton.symbolSize,
                  ),
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: widget.onPressed,
                        onHover: (value) => setState(() => _hover = value),
                        onFocusChange: (value) =>
                            setState(() => _focus = value),
                        customBorder: const CircleBorder(),
                        mouseCursor: SystemMouseCursors.click,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
