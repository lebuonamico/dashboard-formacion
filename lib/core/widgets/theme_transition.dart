import 'dart:ui' as ui;

import 'package:app_finnegans/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transition between the light and dark themes.
///
/// Interpolating the `ThemeData` (MaterialApp's default) rebuilds the whole app
/// on every frame and restarts every widget's color animations, so it stutters.
/// Instead the theme switches at once and a snapshot of the previous look fades
/// out on top: animating an image's opacity rebuilds nothing.
///
/// Goes in `MaterialApp.builder`, with `themeAnimationDuration: Duration.zero`.
class ThemeTransition extends ConsumerStatefulWidget {
  final Widget child;

  const ThemeTransition({super.key, required this.child});

  @override
  ConsumerState<ThemeTransition> createState() => _ThemeTransitionState();
}

class _ThemeTransitionState extends ConsumerState<ThemeTransition>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 350);

  final _screen = GlobalKey();
  late final _fade = AnimationController(vsync: this, duration: _duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _releaseCapture();
    });
  late final _opacity = ReverseAnimation(
    CurvedAnimation(parent: _fade, curve: Curves.easeInOut),
  );

  /// How the app looked with the previous theme, while it fades out.
  ui.Image? _snapshot;

  /// The listener runs as soon as the preference changes, before the app
  /// rebuilds: the layer still has the previous theme painted.
  void _capture() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final limit = _screen.currentContext?.findRenderObject();
    if (limit is! RenderRepaintBoundary || !limit.hasSize) return;

    final ui.Image image;
    try {
      image = limit.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } on Object {
      // If the layer cannot be captured in this frame, the theme switches
      // without the fade: it never blocks the change.
      return;
    }
    _snapshot?.dispose();
    setState(() => _snapshot = image);
    _fade.forward(from: 0);
  }

  void _releaseCapture() {
    if (!mounted) return;
    setState(() {
      _snapshot?.dispose();
      _snapshot = null;
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(themeModeProvider, (previous, current) {
      if (previous != current) _capture();
    });

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        RepaintBoundary(key: _screen, child: widget.child),
        if (_snapshot case final capture?)
          Positioned.fill(
            // Does not intercept taps: the app already responds with the new theme.
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _opacity,
                child: RawImage(image: capture, fit: BoxFit.fill),
              ),
            ),
          ),
      ],
    );
  }
}
