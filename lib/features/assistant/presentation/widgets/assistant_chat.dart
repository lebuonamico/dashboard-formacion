import 'dart:math' as math;

import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/domain/chat_message.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/presentation/assistant_destination.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_chat_notifier.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_chat_panel.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_conversation.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_editor.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_launcher_button.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_motion.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Where the button and the panel sit inside the visible area.
class AssistantLayout {
  /// [AssistantLauncherButton.symbolSize] plus a 2 px border on each side.
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
  Uri? _location;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _savedOffset = _scroll.offset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri;
    final previous = _location;
    _location = location;
    if (previous == null || previous == location) return;
    // Full screen the chat hides the screen, so the browser's back button
    // minimizes it instead of changing the screen unseen. The conversation is
    // kept. Changing the provider cannot happen during a build.
    if (context.windowSize != WindowSize.compact) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(assistantChatProvider).open) _minimize();
    });
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
    // The on-screen keyboard's Enter writes a new line; the button sends.
    if (usesSoftKeyboard) return KeyEventResult.ignored;
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
    final duration = assistantMotion(context, 180);
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
    final duration = assistantMotion(context, 220);
    // On phones the open chat takes the whole screen.
    final fullScreen = context.windowSize == WindowSize.compact;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AssistantLayout.forSize(constraints.biggest);
        final margin = layout.margin;
        final width = fullScreen
            ? constraints.maxWidth
            : math.max(0.0, math.min(480.0, constraints.maxWidth - margin * 2));
        final height = fullScreen
            ? constraints.maxHeight
            : math.max(
                0.0,
                math.min(
                  740.0,
                  constraints.maxHeight - layout.basePanel - margin,
                ),
              );
        final compact = height < 430;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // A single mounted panel avoids reattaching controllers when it
            // is minimized.
            Positioned(
              right: fullScreen ? 0 : margin,
              bottom: fullScreen ? 0 : layout.basePanel,
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
                        child: AssistantChatPanel(
                          height: height,
                          fullScreen: fullScreen,
                          header: AssistantChatHeader(
                            width: width,
                            compact: compact,
                            fullScreen: fullScreen,
                            onCopy: status.messages.isEmpty
                                ? null
                                : _copyConversation,
                            onClear: _clearConversation,
                            onMinimize: _minimize,
                          ),
                          conversation: AssistantConversation(
                            status: status,
                            real: real,
                            controller: _scroll,
                            onSuggestion: _useSuggestion,
                          ),
                          editor: AssistantEditor(
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
                    child: AssistantLauncherButton(
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
