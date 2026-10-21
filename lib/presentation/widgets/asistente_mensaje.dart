import 'dart:math' as math;

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/mensaje_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// La clave estable del mensaje conserva esta transición entre reconstrucciones.
class AsistenteMensaje extends StatelessWidget {
  final MensajeChat mensaje;

  const AsistenteMensaje({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colores = context.colores;
    final texto = TextStyle(
      fontSize: 14,
      height: 1.65,
      color: colores.textoIntermedio,
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
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colores.iaBurbujaUsuario,
                    )
                  : null,
              color: mensaje.esUsuario ? null : cs.surface,
              border: Border.all(color: cs.outlineVariant),
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
                      Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: cs.onSurfaceVariant,
                      )
                    else
                      const AsistenteSimbolo(size: 23),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        // La pantalla visible no prueba la fuente de la respuesta.
                        mensaje.esUsuario ? 'Vos' : 'Asistente IA',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
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
                          listBullet: texto.copyWith(color: colores.ia.texto),
                          a: TextStyle(
                            color: cs.primary,
                            decoration: TextDecoration.underline,
                          ),
                          code: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            fontFamily: 'monospace',
                            color: colores.ia.texto,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: colores.ia.fondo,
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          codeblockPadding: const EdgeInsets.all(12),
                          blockquote: texto.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          blockquoteDecoration: BoxDecoration(
                            color: colores.ia.fondo,
                            border: Border(
                              left: BorderSide(
                                color: colores.ia.texto,
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
                          tableHeadCellsDecoration: BoxDecoration(
                            color: colores.ia.fondo,
                          ),
                          tableBorder: TableBorder.all(
                            color: cs.outlineVariant,
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
  Widget build(BuildContext context) {
    final colores = context.colores;
    final gradiente = colores.iaGradienteSimbolo;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradiente,
            stops: const [0, .63, 1],
          ),
          border: Border.all(
            color: colores.sobreGradiente.withValues(alpha: .33),
          ),
          boxShadow: halo
              ? [
                  BoxShadow(
                    color: gradiente[1].withValues(alpha: .16),
                    blurRadius: 28,
                    spreadRadius: 7,
                  ),
                  BoxShadow(
                    color: gradiente[2].withValues(alpha: .12),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(painter: _NucleoIaPainter(colores.sobreGradiente)),
      ),
    );
  }
}

class _NucleoIaPainter extends CustomPainter {
  /// Color de la órbita y los destellos, que se dibujan sobre el gradiente.
  final Color luz;

  const _NucleoIaPainter(this.luz);

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final centro = Offset(size.width * .48, size.height * .5);
    final orbita = Paint()
      ..color = luz.withValues(alpha: .6)
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
    final pintura = Paint()..color = luz;
    void destello(Offset c, double r) {
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + r * .14, c.dy - r * .14, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + r * .14, c.dy + r * .14, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - r * .14, c.dy + r * .14, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - r * .14, c.dy - r * .14, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, pintura);
    }

    destello(centro, lado * .245);
    destello(Offset(lado * .76, lado * .25), lado * .09);
    canvas.drawCircle(Offset(lado * .23, lado * .74), lado * .035, pintura);
  }

  @override
  bool shouldRepaint(_NucleoIaPainter oldDelegate) => oldDelegate.luz != luz;
}
