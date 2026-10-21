import 'dart:ui' as ui;

import 'package:app_finnegans/presentation/providers/tema_provider.dart';
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
class TransicionTema extends ConsumerStatefulWidget {
  final Widget child;

  const TransicionTema({super.key, required this.child});

  @override
  ConsumerState<TransicionTema> createState() => _TransicionTemaState();
}

class _TransicionTemaState extends ConsumerState<TransicionTema>
    with SingleTickerProviderStateMixin {
  static const _duracion = Duration(milliseconds: 350);

  final _pantalla = GlobalKey();
  late final _fundido = AnimationController(vsync: this, duration: _duracion)
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _liberarCaptura();
    });
  late final _opacidad = ReverseAnimation(
    CurvedAnimation(parent: _fundido, curve: Curves.easeInOut),
  );

  /// Cómo se veía la app con el tema anterior, mientras se desvanece.
  ui.Image? _captura;

  /// El listener corre apenas cambia la preferencia, antes de que la app se
  /// reconstruya: la capa todavía tiene pintado el tema anterior.
  void _capturar() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final limite = _pantalla.currentContext?.findRenderObject();
    if (limite is! RenderRepaintBoundary || !limite.hasSize) return;

    final ui.Image imagen;
    try {
      imagen = limite.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } on Object {
      // Si la capa no se puede capturar en este frame, el tema cambia sin
      // fundido: nunca bloquea el cambio.
      return;
    }
    _captura?.dispose();
    setState(() => _captura = imagen);
    _fundido.forward(from: 0);
  }

  void _liberarCaptura() {
    if (!mounted) return;
    setState(() {
      _captura?.dispose();
      _captura = null;
    });
  }

  @override
  void dispose() {
    _fundido.dispose();
    _captura?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(temaProvider, (anterior, actual) {
      if (anterior != actual) _capturar();
    });

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        RepaintBoundary(key: _pantalla, child: widget.child),
        if (_captura case final captura?)
          Positioned.fill(
            // No intercepta toques: la app ya responde con el tema nuevo.
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _opacidad,
                child: RawImage(image: captura, fit: BoxFit.fill),
              ),
            ),
          ),
      ],
    );
  }
}
