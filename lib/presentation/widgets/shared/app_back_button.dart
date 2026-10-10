import 'package:flutter/material.dart';

/// Flecha para volver atrás. En lugar del ripple de Material (un círculo que
/// aparece y se borra de golpe), el feedback es continuo: un fondo circular que
/// se desvanece al pasar el mouse, un leve empuje de la flecha y un pequeño
/// achique al presionar.
class AppBackButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color color;
  final String tooltip;

  const AppBackButton({
    super.key,
    required this.onPressed,
    this.color = const Color(0xFF0F172A),
    this.tooltip = 'Volver',
  });

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton> {
  static const _duracion = Duration(milliseconds: 160);

  bool _hover = false;
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final colorFondo = _presionado
        ? const Color(0x1A0F172A)
        : _hover
        ? const Color(0x0F0F172A)
        : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _presionado ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: _duracion,
          curve: Curves.easeOut,
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: colorFondo),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              // Sin ripple ni resaltado propio: el feedback lo da el fondo de
              // arriba.
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              onTap: widget.onPressed,
              onHover: (hover) => setState(() => _hover = hover),
              onHighlightChanged: (presionado) =>
                  setState(() => _presionado = presionado),
              child: Center(
                child: AnimatedSlide(
                  offset: Offset(_hover ? -0.1 : 0, 0),
                  duration: _duracion,
                  curve: Curves.easeOut,
                  child: Icon(Icons.arrow_back, size: 22, color: widget.color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
