import 'package:flutter/material.dart';

/// Hace aparecer [child] con un fundido al montarse. Se usa en el contenido que
/// reemplaza a un indicador de carga, para que no salte de golpe. Como sólo
/// anima al montarse, los cambios posteriores (filtros, paginación) no
/// vuelven a animar.
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
      builder: (context, opacidad, hijo) =>
          Opacity(opacity: opacidad, child: hijo),
      child: child,
    );
  }
}
