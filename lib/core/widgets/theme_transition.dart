import 'dart:ui' as ui;

import 'package:app_finnegans/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transición al cambiar entre tema claro y oscuro.
///
/// Interpolar el `ThemeData` (lo que hace `MaterialApp` por defecto)
/// reconstruye toda la app en cada frame y además reinicia las animaciones de
/// color de cada widget, así que se ve trabado. En su lugar el tema cambia de
/// golpe y, encima, se desvanece una captura de cómo se veía la pantalla
/// antes: animar la opacidad de una imagen no reconstruye nada.
///
/// Va en `MaterialApp.builder`, con `themeAnimationDuration: Duration.zero`.
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

  /// Cómo se veía la app con el tema anterior, mientras se desvanece.
  ui.Image? _snapshot;

  /// El listener corre apenas cambia la preferencia, antes de que la app se
  /// reconstruya: la capa todavía tiene pintado el tema anterior.
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
      // Si la capa no se puede capturar en este frame, el tema cambia sin
      // fundido: nunca bloquea el cambio.
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
            // No intercepta toques: la app ya responde con el tema nuevo.
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
