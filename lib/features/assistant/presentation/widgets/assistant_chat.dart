import 'dart:math' as math;

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/domain/chat_message.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_context_service.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_chat_provider.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_message.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tamaño del símbolo del botón flotante del asistente.
const double _symbolSize = 52;

/// Posición del botón y del panel dentro del área visible.
class AssistantLayout {
  /// Símbolo de [_symbolSize] más el borde de 2 px de cada lado.
  static const buttonDiameter = 56.0;

  /// El badge de Netlify del deploy mide ~170 px de ancho y está a ~16 px de
  /// la esquina inferior derecha. El botón va a su izquierda, centrado en su
  /// misma línea, dentro de la franja libre que dejan todas las pantallas al
  /// pie ([bottomFloatingReserve]).
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
    // En ventanas muy angostas no puede quedar fuera de la pantalla.
    final buttonRight = math.max(
      margin,
      math.min(_rightNextToBadge, available.width - buttonDiameter - margin),
    );
    return AssistantLayout._(margin, buttonRight, _baseNextToBadge, clearance);
  }
}

/// Copiloto del AppShell autenticado; su estado vive al cambiar de módulo.
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
    // No tocar el borrador ni la conexión de entrada al recibir una respuesta.
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
    // Consumir solo Enter: también durante la espera, sin borrar el borrador.
    return KeyEventResult.handled;
  }

  void _minimize() {
    final status = ref.read(assistantChatProvider);
    _lastOnMinimize = status.messages.lastOrNull;
    _errorOnMinimize = status.error;
    ref.read(assistantChatProvider.notifier).close();
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.delete_outline_rounded, color: context.colors.ai.text),
        title: const Text('¿Limpiar esta conversación?'),
        content: const Text(
          'Se eliminarán los mensajes y el borrador del asistente. Los datos del Dashboard se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.ai.text,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpiar conversación'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notice), duration: const Duration(seconds: 2)),
    );
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

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(assistantChatProvider);
    final real = ref.watch(aiRealContextProvider);
    final uri = GoRouterState.of(context).uri;
    final destination = AssistantDestination.fromUri(uri);
    ref.listen(assistantChatProvider, _updateScroll);
    ref.listen(authControllerProvider.select((auth) => auth.email), (
      prev,
      next,
    ) {
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
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Un solo panel montado evita reanexar controladores al minimizar.
            Positioned(
              right: margin,
              bottom: layout.basePanel,
              width: width,
              height: height,
              child: IgnorePointer(
                ignoring: !status.open,
                child: ExcludeFocus(
                  excluding: !status.open,
                  child: ExcludeSemantics(
                    excluding: !status.open,
                    child: AnimatedSlide(
                      offset: status.open
                          ? Offset.zero
                          : const Offset(.015, .035),
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
                            child: _panel(
                              status,
                              destination,
                              real,
                              width,
                              height,
                            ),
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
              child: IgnorePointer(
                ignoring: status.open,
                child: ExcludeFocus(
                  excluding: status.open,
                  child: ExcludeSemantics(
                    excluding: status.open,
                    child: AnimatedScale(
                      scale: status.open ? .8 : 1,
                      duration: duration,
                      child: AnimatedOpacity(
                        opacity: status.open ? 0 : 1,
                        duration: duration,
                        child: _CopilotButton(
                          onPressed: ref
                              .read(assistantChatProvider.notifier)
                              .open,
                        ),
                      ),
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

  Widget _panel(
    ChatState status,
    AssistantDestination destination,
    bool real,
    double width,
    double height,
  ) {
    final compact = height < 430;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final header = _header(status, width, compact);
    final conversation = _conversation(status, real);
    final editor = _editor(status, destination, compact);
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
            // Con teclado y muy poca altura, todo el panel sigue siendo accesible.
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

  Widget _header(ChatState status, double width, bool compact) {
    final twoRows =
        !compact &&
        (width < 430 || MediaQuery.textScalerOf(context).scale(16) > 20);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionHeader(
          Icons.copy_outlined,
          'Copiar conversación',
          status.messages.isEmpty ? null : _copyConversation,
        ),
        _actionHeader(
          Icons.delete_outline_rounded,
          'Limpiar conversación',
          _clearConversation,
        ),
        _actionHeader(Icons.remove_rounded, 'Minimizar asistente', _minimize),
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
                      style: TextStyle(
                        color: colors.overGradient,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.25,
                        height: 1.3,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tu copiloto de capacitación',
                        style: TextStyle(
                          color: colors.overGradient.withValues(alpha: .8),
                          fontSize: 11.5,
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

  Widget _actionHeader(IconData icon, String tooltip, VoidCallback? action) {
    final overGradient = context.colors.overGradient;
    return IconButton(
      tooltip: tooltip,
      onPressed: action,
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

  Widget _conversation(ChatState status, bool real) => ClipRect(
    key: const Key('asistente_viewport'),
    child: Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        key: const Key('asistente_scroll'),
        controller: _scroll,
        primary: false,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (status.messages.isEmpty &&
                !status.sending &&
                status.error == null)
              _welcome(status.sending)
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
            if (status.error != null) _error(status),
          ],
        ),
      ),
    ),
  );

  Widget _error(ChatState status) {
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
                    style: TextStyle(
                      color: warning.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    status.error!,
                    style: TextStyle(
                      color: context.colors.intermediateText,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  if (status.canRetry) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('asistente_reintentar'),
                      onPressed: status.sending
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
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
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

  Widget _editor(
    ChatState status,
    AssistantDestination destination,
    bool compact,
  ) => ListenableBuilder(
    listenable: Listenable.merge([_text, _focus]),
    builder: (context, _) {
      final value = _text.value;
      final canSend =
          !status.sending &&
          value.text.trim().isNotEmpty &&
          (!value.composing.isValid || value.composing.isCollapsed);
      final cs = context.colorScheme;
      final colors = context.colors;
      final accent = colors.ai.text;
      final noteStyle = TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 10.5,
        height: 1.4,
      );
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
            AnimatedContainer(
              duration: _movement(context, 140),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _focus.hasFocus ? accent : cs.outline,
                  width: 1.5,
                ),
                boxShadow: [
                  if (_focus.hasFocus)
                    BoxShadow(
                      color: accent.withValues(alpha: .07),
                      blurRadius: 10,
                    ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Focus(
                      canRequestFocus: false,
                      onKeyEvent: (_, event) => _editorKey(event, destination),
                      child: TextField(
                        key: const Key('asistente_input'),
                        controller: _text,
                        focusNode: _focus,
                        maxLength: AssistantContextService.maxQuestion,
                        minLines: 1,
                        maxLines: compact ? 2 : 4,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorColor: accent,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        // El recuadro lo dibuja el contenedor: el campo va
                        // sin relleno ni bordes propios del tema.
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
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedContainer(
                      duration: _movement(context, 140),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: canSend
                            ? LinearGradient(colors: colors.aiSendGradient)
                            : null,
                        color: canSend ? null : cs.surfaceContainer,
                      ),
                      child: IconButton(
                        tooltip: status.sending
                            ? 'Esperá la respuesta para enviar otra consulta'
                            : 'Enviar pregunta',
                        onPressed: canSend ? () => _send(destination) : null,
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
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    status.sending
                        ? 'Podés preparar tu próxima pregunta'
                        : 'Enter para enviar · Shift + Enter para otra línea',
                    textAlign: TextAlign.center,
                    style: noteStyle,
                  ),
                  if (value.text.length > 1000)
                    Text(
                      '${value.text.length}/${AssistantContextService.maxQuestion}',
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
          ],
        ),
      );
    },
  );

  Widget _welcome(bool sending) {
    final cs = context.colorScheme;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 12),
      child: Column(
        children: [
          const AssistantSymbol(size: 68, halo: true),
          const SizedBox(height: 22),
          Text(
            '¡Hola! ¿En qué puedo ayudarte?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 23,
              height: 1.25,
              letterSpacing: -.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Analizá indicadores, explorá capacitaciones y encontrá respuestas sobre tu organización.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
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
              const suggestions = [
                (Icons.insights_rounded, '¿Cómo viene el cumplimiento?'),
                (Icons.groups_outlined, '¿Qué equipos necesitan atención?'),
                (Icons.auto_stories_outlined, '¿Qué cursos hay disponibles?'),
                (
                  Icons.upload_file_outlined,
                  '¿Cómo funciona la importación de nómina?',
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (icon, question) in suggestions)
                    SizedBox(
                      width: width,
                      child: OutlinedButton(
                        onPressed: sending
                            ? null
                            : () {
                                _text.value = TextEditingValue(
                                  text: question,
                                  selection: TextSelection.collapsed(
                                    offset: question.length,
                                  ),
                                );
                                _focus.requestFocus();
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.intermediateText,
                          backgroundColor: cs.surface,
                          padding: const EdgeInsets.all(14),
                          minimumSize: Size(0, columns ? 100 : 66),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
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
