import 'package:flutter/material.dart';

/// Fades [child] in when it mounts. Used for content that replaces a
/// loading indicator, so it does not pop in. It only animates on mount: later
/// changes (filters, pagination) do not animate again.
class FadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const FadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: child,
    );
  }
}
