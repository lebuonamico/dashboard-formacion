import 'dart:math' as math;

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/domain/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// La clave estable del mensaje conserva esta transición entre reconstrucciones.
class AssistantMessage extends StatelessWidget {
  final ChatMessage message;

  const AssistantMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = context.colors;
    final text = context.textTheme.bodyMedium!.copyWith(
      height: 1.65,
      color: colors.intermediateText,
    );
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: message.isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            width: message.isUser ? null : double.infinity,
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * (message.isUser ? .88 : 1),
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: message.isUser
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors.aiUserBubble,
                    )
                  : null,
              color: message.isUser ? null : cs.surface,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(message.isUser ? 20 : 6),
                topRight: Radius.circular(message.isUser ? 6 : 20),
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
                    if (message.isUser)
                      Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: cs.onSurfaceVariant,
                      )
                    else
                      const AssistantSymbol(size: 23),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        // La pantalla visible no prueba la fuente de la respuesta.
                        message.isUser ? 'Vos' : 'Asistente IA',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                if (message.isUser)
                  SelectableText(message.text, style: text)
                else
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    fitContent: false,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: text,
                          strong: const TextStyle(fontWeight: FontWeight.w700),
                          h1: context.textTheme.titleLarge!.copyWith(
                            color: text.color,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.4,
                          ),
                          h2: context.textTheme.titleMedium!.copyWith(
                            color: text.color,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.3,
                          ),
                          h3: context.textTheme.bodyLarge!.copyWith(
                            color: text.color,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                          h4: context.textTheme.bodyLarge!.copyWith(
                            color: text.color,
                            fontWeight: FontWeight.w700,
                          ),
                          h5: text.copyWith(fontWeight: FontWeight.w700),
                          h6: text.copyWith(fontWeight: FontWeight.w700),
                          blockSpacing: 12,
                          listIndent: 20,
                          listBullet: text.copyWith(color: colors.ai.text),
                          a: TextStyle(
                            color: cs.primary,
                            decoration: TextDecoration.underline,
                          ),
                          code: context.textTheme.bodySmall?.copyWith(
                            height: 1.5,
                            fontFamily: 'monospace',
                            color: colors.ai.text,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: colors.ai.background,
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          codeblockPadding: const EdgeInsets.all(12),
                          blockquote: text.copyWith(color: cs.onSurfaceVariant),
                          blockquoteDecoration: BoxDecoration(
                            color: colors.ai.background,
                            border: Border(
                              left: BorderSide(color: colors.ai.text, width: 3),
                            ),
                          ),
                          blockquotePadding: const EdgeInsets.all(12),
                          tableBody: context.textTheme.bodySmall!.copyWith(
                            color: text.color,
                            height: 1.55,
                          ),
                          tableHead: context.textTheme.bodySmall!.copyWith(
                            color: text.color,
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
                            color: colors.ai.background,
                          ),
                          tableBorder: TableBorder.all(
                            color: cs.outlineVariant,
                            width: .7,
                          ),
                        ),
                    // No descargar imágenes que pueda producir el modelo.
                    imageBuilder: (uri, title, alt) =>
                        Text(alt ?? 'Imagen', style: text),
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
class AssistantSymbol extends StatelessWidget {
  final double size;
  final bool halo;
  const AssistantSymbol({super.key, this.size = 40, this.halo = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gradient = colors.aiSymbolGradient;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
            stops: const [0, .63, 1],
          ),
          border: Border.all(color: colors.overGradient.withValues(alpha: .33)),
          boxShadow: halo
              ? [
                  BoxShadow(
                    color: gradient[1].withValues(alpha: .16),
                    blurRadius: 28,
                    spreadRadius: 7,
                  ),
                  BoxShadow(
                    color: gradient[2].withValues(alpha: .12),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(painter: _AiCorePainter(colors.overGradient)),
      ),
    );
  }
}

class _AiCorePainter extends CustomPainter {
  /// Color de la órbita y los destellos, que se dibujan sobre el gradiente.
  final Color light;

  const _AiCorePainter(this.light);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width * .48, size.height * .5);
    final orbit = Paint()
      ..color = light.withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, side * .018)
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.55);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset.zero,
        width: side * .75,
        height: side * .5,
      ),
      .1,
      math.pi * 1.45,
      false,
      orbit,
    );
    canvas.restore();
    final paint = Paint()..color = light;
    void flash(Offset c, double r) {
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + r * .14, c.dy - r * .14, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + r * .14, c.dy + r * .14, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - r * .14, c.dy + r * .14, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - r * .14, c.dy - r * .14, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, paint);
    }

    flash(center, side * .245);
    flash(Offset(side * .76, side * .25), side * .09);
    canvas.drawCircle(Offset(side * .23, side * .74), side * .035, paint);
  }

  @override
  bool shouldRepaint(_AiCorePainter oldDelegate) => oldDelegate.light != light;
}
