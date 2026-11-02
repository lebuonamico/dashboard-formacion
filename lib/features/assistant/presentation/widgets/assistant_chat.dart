import 'package:app_finnegans/core/widgets/feedback.dart';
import 'dart:math' as math;

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/domain/chat_message.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query_planner.dart';
import 'package:app_finnegans/features/assistant/presentation/assistant_destination.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_chat_notifier.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_message.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const double _symbolSize = 52;

/// Where the button and the panel sit inside the visible area.
class AssistantLayout {
  /// [_symbolSize] plus a 2 px border on each side.
  static const buttonDiameter = 56.0;

  /// The deploy's Netlify badge is ~170 px wide and ~16 px from the bottom
  /// right corner. The button goes to its left, on the same line, inside the
  /// free strip every screen leaves at the bottom ([bottomFloatingReserve]).
  static const _rightNextToBadge = 200.0;
  static const _baseNextToBadge = 8.0;

  final double margin;
  final double buttonRight;
  final double buttonBase;
  final double basePanel;

  const AssistantLayout._(
    this.margin,
    this.buttonRight,
    this.buttonBase,
    this.basePanel,
  );

  factory AssistantLayout.forSize(Size available) {
    final margin = available.width < 600 ? 12.0 : 20.0;
    final clearance = math.min(
      (available.height * .1).clamp(56.0, 96.0),
      available.height * .2,
    );
    // On very narrow windows it must not end up off screen.
    final buttonRight = math.max(
      margin,
      math.min(_rightNextToBadge, available.width - buttonDiameter - margin),
    );
    return AssistantLayout._(margin, buttonRight, _baseNextToBadge, clearance);
  }
}

/// Lives in the authenticated AppShell, so its state survives navigation.
class AssistantChat extends ConsumerStatefulWidget {
  const AssistantChat({super.key});

  @override
  ConsumerState<AssistantChat> createState() => _AssistantChatState();
}

class _AssistantChatState extends ConsumerState<AssistantChat> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  double _savedOffset = 0;
  ChatMessage? _lastOnMinimize;
  String? _errorOnMinimize;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _savedOffset = _scroll.offset);
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(AssistantDestination destination) async {
    if (ref.read(assistantChatProvider).sending) return;
    final value = _text.value;
    if (value.text.trim().isEmpty ||
        (value.composing.isValid && !value.composing.isCollapsed)) {
      return;
    }
    final submission = ref
        .read(assistantChatProvider.notifier)
        .send(value.text, destination);
    if (ref.read(assistantChatProvider).sending) _text.clear();
    // The draft and the input connection are left alone when the answer
    // arrives.
    await submission;
  }

  KeyEventResult _editorKey(KeyEvent event, AssistantDestination destination) {
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        (_text.value.composing.isValid && !_text.value.composing.isCollapsed)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) _send(destination);
    // Only Enter is consumed: also while waiting, keeping the draft.
    return KeyEventResult.handled;
  }

  void _minimize() {
    final status = ref.read(assistantChatProvider);
    _lastOnMinimize = status.messages.lastOrNull;
    _errorOnMinimize = status.error;
    ref.read(assistantChatProvider.notifier).close();
  }

  Future<void> _clearConversation() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: '¿Limpiar esta conversación?',
      message:
          'Se eliminarán los mensajes y el borrador del asistente. Los datos del Dashboard se conservan.',
      confirmLabel: 'Limpiar conversación',
      confirmColor: context.colors.ai.text,
    );
    if (!mounted || !confirmed) return;
    ref.read(assistantChatProvider.notifier).clear();
    _text.clear();
    _lastOnMinimize = null;
    _errorOnMinimize = null;
  }

  Future<void> _copyConversation() async {
    final messages = ref.read(assistantChatProvider).messages;
    if (messages.isEmpty) return;
    final conversation = messages
        .map((m) => '${m.isUser ? 'Usuario' : 'Asistente'}:\n${m.text}')
        .join('\n\n');
    String notice;
    try {
      await Clipboard.setData(ClipboardData(text: conversation));
      notice = 'Conversación copiada';
    } catch (_) {
      notice = 'No se pudo copiar. Revisá los permisos del portapapeles.';
    }
    if (!mounted) return;
    showAppSnackBar(context, notice);
  }

  void _updateScroll(ChatState? previous, ChatState next) {
    if (!next.open) return;
    final last = next.messages.lastOrNull;
    final messageChange = !identical(previous?.messages.lastOrNull, last);
    final opening = previous?.open != true;
    final pendingResponse = opening && !identical(_lastOnMinimize, last);
    final following = !_scroll.hasClients || _scroll.position.extentAfter < 72;
    final showMessage =
        last != null &&
        (pendingResponse || (messageChange && (last.isUser || following)));
    final showError =
        next.error != null &&
        ((opening && _errorOnMinimize != next.error) ||
            (previous?.error != next.error && following));
    if (!opening && !messageChange && !showError) return;
    final duration = _movement(context, 180);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (showMessage) {
        if (!identical(
          ref.read(assistantChatProvider).messages.lastOrNull,
          last,
        )) {
          return;
        }
        if (last.isUser) {
          if (duration == Duration.zero) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          } else {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: duration,
              curve: Curves.easeOut,
            );
          }
          return;
        }
        final render = GlobalObjectKey(last).currentContext?.findRenderObject();
        if (render != null) {
          _scroll.position.ensureVisible(
            render,
            alignment: 0,
            duration: duration,
            curve: Curves.easeOut,
          );
        }
      } else if (showError) {
        if (duration == Duration.zero) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        } else {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: duration,
            curve: Curves.easeOut,
          );
        }
      } else if (opening || last == null) {
        _scroll.jumpTo(
          last == null
              ? 0
              : _savedOffset.clamp(0, _scroll.position.maxScrollExtent),
        );
      }
    });
  }

  void _useSuggestion(String question) {
    _text.value = TextEditingValue(
      text: question,
      selection: TextSelection.collapsed(offset: question.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(assistantChatProvider);
    final real = ref.watch(aiRealContextProvider);
    final uri = GoRouterState.of(context).uri;
    final destination = assistantDestinationFor(uri);
    ref.listen(assistantChatProvider, _updateScroll);
    ref.listen(authProvider.select((auth) => auth.email), (prev, next) {
      if (prev != next) {
        _text.clear();
        _focus.unfocus();
        _savedOffset = 0;
        _lastOnMinimize = null;
        _errorOnMinimize = null;
      }
    });
    final duration = _movement(context, 220);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AssistantLayout.forSize(constraints.biggest);
        final margin = layout.margin;
        final width = math.max(
          0.0,
          math.min(480.0, constraints.maxWidth - margin * 2),
        );
        final height = math.max(
          0.0,
          math.min(740.0, constraints.maxHeight - layout.basePanel - margin),
        );
        final compact = height < 430;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // A single mounted panel avoids reattaching controllers when it
            // is minimized.
            Positioned(
              right: margin,
              bottom: layout.basePanel,
              width: width,
              height: height,
              child: _Showing(
                visible: status.open,
                duration: duration,
                child: AnimatedSlide(
                  offset: status.open ? Offset.zero : const Offset(.015, .035),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: AnimatedScale(
                    scale: status.open ? 1 : .96,
                    alignment: Alignment.bottomRight,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: status.open ? 1 : 0,
                      duration: duration,
                      child: TickerMode(
                        enabled: status.open,
                        child: _ChatPanel(
                          height: height,
                          header: _ChatHeader(
                            width: width,
                            compact: compact,
                            onCopy: status.messages.isEmpty
                                ? null
                                : _copyConversation,
                            onClear: _clearConversation,
                            onMinimize: _minimize,
                          ),
                          conversation: _Conversation(
                            status: status,
                            real: real,
                            controller: _scroll,
                            onSuggestion: _useSuggestion,
                          ),
                          editor: _Editor(
                            status: status,
                            compact: compact,
                            text: _text,
                            focus: _focus,
                            onKey: (event) => _editorKey(event, destination),
                            onSend: () => _send(destination),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: layout.buttonRight,
              bottom: layout.buttonBase,
              child: _Showing(
                visible: !status.open,
                duration: duration,
                child: AnimatedScale(
                  scale: status.open ? .8 : 1,
                  duration: duration,
                  child: AnimatedOpacity(
                    opacity: status.open ? 0 : 1,
                    duration: duration,
                    child: _CopilotButton(
                      onPressed: ref.read(assistantChatProvider.notifier).open,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ignores pointer, focus and semantics while hidden.
class _Showing extends StatelessWidget {
  final bool visible;
  final Duration duration;
  final Widget child;

  const _Showing({
    required this.visible,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeFocus(
      excluding: !visible,
      child: ExcludeSemantics(excluding: !visible, child: child),
    ),
  );
}

class _ChatPanel extends StatelessWidget {
  final double height;
  final Widget header;
  final Widget conversation;
  final Widget editor;

  const _ChatPanel({
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

class _ChatHeader extends StatelessWidget {
  final double width;
  final bool compact;
  final VoidCallback? onCopy;
  final VoidCallback onClear;
  final VoidCallback onMinimize;

  const _ChatHeader({
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

class _Conversation extends StatelessWidget {
  final ChatState status;
  final bool real;
  final ScrollController controller;
  final ValueChanged<String> onSuggestion;

  const _Conversation({
    required this.status,
    required this.real,
    required this.controller,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) => ClipRect(
    key: const Key('asistente_viewport'),
    child: Scrollbar(
      controller: controller,
      child: SingleChildScrollView(
        key: const Key('asistente_scroll'),
        controller: controller,
        primary: false,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ContextNotice(real: real),
            if (status.messages.isEmpty &&
                !status.sending &&
                status.error == null)
              _Welcome(sending: status.sending, onSuggestion: onSuggestion)
            else ...[
              const SizedBox(height: 20),
              for (final message in status.messages)
                Padding(
                  key: GlobalObjectKey(message),
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AssistantMessage(message: message),
                ),
            ],
            if (status.sending) const _AnalyzingQuery(),
            if (status.error case final error?)
              _ChatError(
                error: error,
                canRetry: status.canRetry,
                sending: status.sending,
              ),
          ],
        ),
      ),
    ),
  );
}

class _ContextNotice extends StatelessWidget {
  final bool real;

  const _ContextNotice({required this.real});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('asistente_aviso'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: context.colors.ai.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.layers_outlined,
          size: 16,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            real
                ? 'Contexto dinámico · Datos disponibles en la aplicación'
                : 'Ayuda conceptual · Indicadores deshabilitados',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChatError extends ConsumerWidget {
  final String error;
  final bool canRetry;
  final bool sending;

  const _ChatError({
    required this.error,
    required this.canRetry,
    required this.sending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warning = context.colors.warning;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warning.background,
          border: Border.all(color: warning.text.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: warning.text, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu consulta sigue disponible',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: warning.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    error,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.intermediateText,
                      height: 1.5,
                    ),
                  ),
                  if (canRetry) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('asistente_reintentar'),
                      onPressed: sending
                          ? null
                          : () => ref
                                .read(assistantChatProvider.notifier)
                                .retry(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Se conserva la misma pregunta. Tu borrador actual no se modifica.',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  final ChatState status;
  final bool compact;
  final TextEditingController text;
  final FocusNode focus;
  final KeyEventResult Function(KeyEvent event) onKey;
  final VoidCallback onSend;

  const _Editor({
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
      duration: _movement(context, 140),
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
                  hintText: 'Preguntale algo sobre la formación...',
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
      duration: _movement(context, 140),
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

class _Welcome extends StatelessWidget {
  static const _suggestions = [
    (Icons.insights_rounded, '¿Cómo viene el cumplimiento?'),
    (Icons.groups_outlined, '¿Qué equipos necesitan atención?'),
    (Icons.auto_stories_outlined, '¿Qué cursos hay disponibles?'),
    (Icons.upload_file_outlined, '¿Cómo funciona la importación de nómina?'),
  ];

  final bool sending;
  final ValueChanged<String> onSuggestion;

  const _Welcome({required this.sending, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 12),
      child: Column(
        children: [
          const AssistantSymbol(size: 68, halo: true),
          const SizedBox(height: 22),
          Text(
            '¡Hola! ¿En qué puedo ayudarte?',
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
              height: 1.25,
              letterSpacing: -.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Analizá indicadores, explorá capacitaciones y encontrá respuestas sobre tu organización.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 360 &&
                  MediaQuery.textScalerOf(context).scale(14) < 19;
              final width = columns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (icon, question) in _suggestions)
                    SizedBox(
                      width: width,
                      child: _SuggestionButton(
                        icon: icon,
                        question: question,
                        tall: columns,
                        onPressed: sending
                            ? null
                            : () => onSuggestion(question),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  final IconData icon;
  final String question;
  final bool tall;
  final VoidCallback? onPressed;

  const _SuggestionButton({
    required this.icon,
    required this.question,
    required this.tall,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.intermediateText,
        backgroundColor: context.colorScheme.surface,
        padding: const EdgeInsets.all(14),
        minimumSize: Size(0, tall ? 100 : 66),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: colors.ai.text),
          const SizedBox(height: 9),
          Text(
            question,
            style: context.textTheme.bodySmall?.copyWith(
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

Duration _movement(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class _CopilotButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CopilotButton({required this.onPressed});

  @override
  State<_CopilotButton> createState() => _CopilotButtonState();
}

class _CopilotButtonState extends State<_CopilotButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final gradient = context.colors.aiSymbolGradient;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _movement(context, 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: .85 + .15 * value, child: child),
      ),
      child: AnimatedScale(
        scale: _hover || _focus ? 1.05 : 1,
        duration: _movement(context, 160),
        child: AnimatedContainer(
          duration: _movement(context, 160),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _focus ? cs.onSurface : cs.surface,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[1].withValues(
                  alpha: _hover || _focus ? .31 : .19,
                ),
                blurRadius: 26,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: gradient[0].withValues(alpha: .19),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Tooltip(
            message: 'Preguntale a la IA',
            child: SizedBox(
              width: _symbolSize,
              height: _symbolSize,
              child: Stack(
                children: [
                  const AssistantSymbol(size: _symbolSize),
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: widget.onPressed,
                        onHover: (value) => setState(() => _hover = value),
                        onFocusChange: (value) =>
                            setState(() => _focus = value),
                        customBorder: const CircleBorder(),
                        mouseCursor: SystemMouseCursors.click,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyzingQuery extends StatefulWidget {
  const _AnalyzingQuery();

  @override
  State<_AnalyzingQuery> createState() => _AnalyzingQueryState();
}

class _AnalyzingQueryState extends State<_AnalyzingQuery>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_movement(context, 1) == Duration.zero) {
      _animation.stop();
      _animation.value = .5;
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Analizando tu consulta',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            const AssistantSymbol(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Analizando tu consulta...',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final wave =
                      (math.sin(_animation.value * math.pi * 2 - i * .9) + 1) /
                      2;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Opacity(
                      opacity: .3 + .7 * wave,
                      child: Transform.translate(
                        offset: Offset(0, -2 * wave),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: context.colors.ai.text,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
