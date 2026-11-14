import 'dart:math' as math;

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_message.dart';
import 'package:flutter/material.dart';

class AssistantChatPanel extends StatelessWidget {
  final double height;
  final Widget header;
  final Widget conversation;
  final Widget editor;

  const AssistantChatPanel({
    super.key,
    required this.height,
    required this.header,
    required this.conversation,
    required this.editor,
  });

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cs = context.colorScheme;
    return Container(
      key: const Key('asistente_panel'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: .15),
            blurRadius: 44,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: context.colors.ai.text.withValues(alpha: .08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: height < 270 * scale
            // With the keyboard up and very little height, the whole panel
            // still scrolls into reach.
            ? SingleChildScrollView(
                primary: false,
                child: Column(
                  children: [
                    header,
                    SizedBox(
                      height: math.max(130, height * .55),
                      child: conversation,
                    ),
                    editor,
                  ],
                ),
              )
            : Column(
                children: [
                  header,
                  Expanded(child: conversation),
                  editor,
                ],
              ),
      ),
    );
  }
}

class AssistantChatHeader extends StatelessWidget {
  final double width;
  final bool compact;
  final VoidCallback? onCopy;
  final VoidCallback onClear;
  final VoidCallback onMinimize;

  const AssistantChatHeader({
    super.key,
    required this.width,
    required this.compact,
    required this.onCopy,
    required this.onClear,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    final twoRows =
        !compact &&
        (width < 430 || MediaQuery.textScalerOf(context).scale(16) > 20);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderAction(
          icon: Icons.copy_outlined,
          tooltip: 'Copiar conversación',
          onPressed: onCopy,
        ),
        _HeaderAction(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Limpiar conversación',
          onPressed: onClear,
        ),
        _HeaderAction(
          icon: Icons.remove_rounded,
          tooltip: 'Minimizar asistente',
          onPressed: onMinimize,
        ),
      ],
    );
    final colors = context.colors;
    return Container(
      key: const Key('asistente_encabezado'),
      padding: EdgeInsets.fromLTRB(
        18,
        compact ? 10 : 18,
        12,
        compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.aiHeaderGradient,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (!compact) ...[
                const AssistantSymbol(size: 42),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asistente IA de Formación',
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: colors.overGradient,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.25,
                        height: 1.3,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tu copiloto de capacitación',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: colors.overGradient.withValues(alpha: .8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!twoRows) ...[const SizedBox(width: 4), actions],
            ],
          ),
          if (twoRows) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final overGradient = context.colors.overGradient;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: overGradient,
        disabledForegroundColor: overGradient.withValues(alpha: .45),
        hoverColor: overGradient.withValues(alpha: .13),
        focusColor: overGradient.withValues(alpha: .2),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}
