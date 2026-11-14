import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query_planner.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_chat_notifier.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_motion.dart';
import 'package:flutter/material.dart';

class AssistantEditor extends StatelessWidget {
  final ChatState status;
  final bool compact;
  final TextEditingController text;
  final FocusNode focus;
  final KeyEventResult Function(KeyEvent event) onKey;
  final VoidCallback onSend;

  const AssistantEditor({
    super.key,
    required this.status,
    required this.compact,
    required this.text,
    required this.focus,
    required this.onKey,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([text, focus]),
    builder: (context, _) {
      final value = text.value;
      final canSend =
          !status.sending &&
          value.text.trim().isNotEmpty &&
          (!value.composing.isValid || value.composing.isCollapsed);
      final cs = context.colorScheme;
      return Container(
        key: const Key('asistente_editor'),
        padding: EdgeInsets.fromLTRB(
          14,
          compact ? 8 : 12,
          14,
          compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EditorField(
              text: text,
              focus: focus,
              compact: compact,
              onKey: onKey,
              sendButton: _SendButton(
                canSend: canSend,
                sending: status.sending,
                onSend: onSend,
              ),
            ),
            if (!compact)
              _EditorNotes(sending: status.sending, length: value.text.length),
          ],
        ),
      );
    },
  );
}

class _EditorField extends StatelessWidget {
  final TextEditingController text;
  final FocusNode focus;
  final bool compact;
  final KeyEventResult Function(KeyEvent event) onKey;
  final Widget sendButton;

  const _EditorField({
    required this.text,
    required this.focus,
    required this.compact,
    required this.onKey,
    required this.sendButton,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final accent = context.colors.ai.text;
    return AnimatedContainer(
      duration: assistantMotion(context, 140),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focus.hasFocus ? accent : cs.outline,
          width: 1.5,
        ),
        boxShadow: [
          if (focus.hasFocus)
            BoxShadow(color: accent.withValues(alpha: .07), blurRadius: 10),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) => onKey(event),
              child: TextField(
                key: const Key('asistente_input'),
                controller: text,
                focusNode: focus,
                maxLength: AssistantQueryPlanner.maxQuestion,
                minLines: 1,
                maxLines: compact ? 2 : 4,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                cursorColor: accent,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  height: 1.5,
                ),
                // The container draws the box: the field goes without the
                // theme's fill and borders.
                decoration: const InputDecoration(
                  hintText: 'Preguntale algo sobre la formación…',
                  hintMaxLines: 2,
                  constraints: BoxConstraints(minHeight: 56),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(6), child: sendButton),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool canSend;
  final bool sending;
  final VoidCallback onSend;

  const _SendButton({
    required this.canSend,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: assistantMotion(context, 140),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: canSend
            ? LinearGradient(colors: colors.aiSendGradient)
            : null,
        color: canSend ? null : context.colorScheme.surfaceContainer,
      ),
      child: IconButton(
        tooltip: sending
            ? 'Esperá la respuesta para enviar otra consulta'
            : 'Enviar pregunta',
        onPressed: canSend ? onSend : null,
        style: IconButton.styleFrom(
          foregroundColor: colors.overGradient,
          disabledForegroundColor: colors.faintText,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: const Icon(Icons.arrow_upward_rounded, size: 21),
      ),
    );
  }
}

class _EditorNotes extends StatelessWidget {
  final bool sending;
  final int length;

  const _EditorNotes({required this.sending, required this.length});

  @override
  Widget build(BuildContext context) {
    final noteStyle = context.textTheme.labelSmall!.copyWith(
      color: context.colorScheme.onSurfaceVariant,
      height: 1.4,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              sending
                  ? 'Podés preparar tu próxima pregunta'
                  : 'Enter para enviar · Shift + Enter para otra línea',
              textAlign: TextAlign.center,
              style: noteStyle,
            ),
            if (length > 1000)
              Text(
                '$length/${AssistantQueryPlanner.maxQuestion}',
                style: noteStyle,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Consultas independientes. No compartas credenciales.',
          textAlign: TextAlign.center,
          style: noteStyle,
        ),
      ],
    );
  }
}
