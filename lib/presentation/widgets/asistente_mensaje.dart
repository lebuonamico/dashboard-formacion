import 'dart:math' as math;

import 'package:app_finnegans/domain/modelos/mensaje_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// La clave estable del mensaje conserva esta transición entre reconstrucciones.
class AsistenteMensaje extends StatelessWidget {
  final MensajeChat mensaje;

  const AsistenteMensaje({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    const texto = TextStyle(
      fontSize: 14,
      height: 1.65,
      color: Color(0xFF263651),
    );
    final reducirMovimiento =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reducirMovimiento
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, valor, child) => Opacity(
        opacity: valor,
        child: Transform.translate(
          offset: Offset(0, (1 - valor) * 6),
          child: child,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: mensaje.esUsuario
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            width: mensaje.esUsuario ? null : double.infinity,
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * (mensaje.esUsuario ? .88 : 1),
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: mensaje.esUsuario
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEDF3FF), Color(0xFFEEEDFD)],
                    )
                  : null,
              color: mensaje.esUsuario ? null : Colors.white,
              border: Border.all(
                color: mensaje.esUsuario
                    ? const Color(0xFFDCE4F8)
                    : const Color(0xFFE4E9F3),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(mensaje.esUsuario ? 20 : 6),
                topRight: Radius.circular(mensaje.esUsuario ? 6 : 20),
                bottomLeft: const Radius.circular(20),
                bottomRight: const Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mensaje.esUsuario)
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: Color(0xFF5D6392),
                      )
                    else
                      const AsistenteSimbolo(size: 23),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        // La pantalla visible no prueba la fuente de la respuesta.
                        mensaje.esUsuario ? 'Vos' : 'Asistente IA',
                        style: const TextStyle(
                          color: Color(0xFF596386),
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                if (mensaje.esUsuario)
                  SelectableText(mensaje.texto, style: texto)
                else
                  MarkdownBody(
                    data: mensaje.texto,
                    selectable: true,
                    fitContent: false,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: texto,
                          strong: const TextStyle(fontWeight: FontWeight.w700),
                          h1: texto.copyWith(
                            fontSize: 20,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.4,
                          ),
                          h2: texto.copyWith(
                            fontSize: 18,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.3,
                          ),
                          h3: texto.copyWith(
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                          h4: texto.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          h5: texto.copyWith(fontWeight: FontWeight.w700),
                          h6: texto.copyWith(fontWeight: FontWeight.w700),
                          blockSpacing: 12,
                          listIndent: 20,
                          listBullet: texto.copyWith(
                            color: const Color(0xFF6B5ECB),
                          ),
                          a: const TextStyle(
                            color: Color(0xFF245BA9),
                            decoration: TextDecoration.underline,
                          ),
                          code: const TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            fontFamily: 'monospace',
                            color: Color(0xFF55429D),
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: const Color(0xFFF1F2FA),
                            border: Border.all(color: const Color(0xFFE2E5F3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          codeblockPadding: const EdgeInsets.all(12),
                          blockquote: texto.copyWith(
                            color: const Color(0xFF546381),
                          ),
                          blockquoteDecoration: const BoxDecoration(
                            color: Color(0xFFF0F3FB),
                            border: Border(
                              left: BorderSide(
                                color: Color(0xFF7B6ACF),
                                width: 3,
                              ),
                            ),
                          ),
                          blockquotePadding: const EdgeInsets.all(12),
                          tableBody: texto.copyWith(
                            fontSize: 12.5,
                            height: 1.55,
                          ),
                          tableHead: texto.copyWith(
                            fontSize: 12.5,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                          // El renderer incorpora scroll horizontal con columnas fijas.
                          tableColumnWidth: FixedColumnWidth(
                            158 *
                                (MediaQuery.textScalerOf(context).scale(14) /
                                        14)
                                    .clamp(1, 1.8),
                          ),
                          tableScrollbarThumbVisibility: true,
                          tablePadding: const EdgeInsets.only(bottom: 12),
                          tableCellsPadding: const EdgeInsets.all(10),
                          tableHeadCellsDecoration: const BoxDecoration(
                            color: Color(0xFFEEF1FB),
                          ),
                          tableBorder: TableBorder.all(
                            color: const Color(0xFFDFE5F0),
                            width: .7,
                          ),
                        ),
                    // No descargar imágenes que pueda producir el modelo.
                    imageBuilder: (uri, title, alt) =>
                        Text(alt ?? 'Imagen', style: texto),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca propia dibujada con Flutter: núcleo, destello y órbita.
class AsistenteSimbolo extends StatelessWidget {
  final double size;
  final bool halo;
  const AsistenteSimbolo({super.key, this.size = 40, this.halo = false});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2463CC), Color(0xFF7755CC), Color(0xFF37B8CB)],
          stops: [0, .63, 1],
        ),
        border: Border.all(color: const Color(0x55FFFFFF)),
        boxShadow: halo
            ? const [
                BoxShadow(
                  color: Color(0x296B59D1),
                  blurRadius: 28,
                  spreadRadius: 7,
                ),
                BoxShadow(
                  color: Color(0x1F3C9CD2),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: CustomPaint(painter: const _NucleoIaPainter()),
    ),
  );
}

class _NucleoIaPainter extends CustomPainter {
  const _NucleoIaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final centro = Offset(size.width * .48, size.height * .5);
    final orbita = Paint()
      ..color = const Color(0x99DBF8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, lado * .018)
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(-.55);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset.zero,
        width: lado * .75,
        height: lado * .5,
      ),
      .1,
      math.pi * 1.45,
      false,
      orbita,
    );
    canvas.restore();
    final luz = Paint()..color = const Color(0xFFF5FDFF);
    void destello(Offset c, double r) {
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + r * .14, c.dy - r * .14, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + r * .14, c.dy + r * .14, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - r * .14, c.dy + r * .14, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - r * .14, c.dy - r * .14, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, luz);
    }

    destello(centro, lado * .245);
    destello(Offset(lado * .76, lado * .25), lado * .09);
    canvas.drawCircle(Offset(lado * .23, lado * .74), lado * .035, luz);
  }

  @override
  bool shouldRepaint(_NucleoIaPainter oldDelegate) => false;
}
