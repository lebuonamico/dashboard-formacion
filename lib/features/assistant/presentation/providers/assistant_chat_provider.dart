import 'dart:async';

import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:app_finnegans/features/assistant/presentation/assistant_labels.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_repository_provider.dart';
import 'package:app_finnegans/features/assistant/domain/chat_message.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_data_provider.dart';

export 'package:app_finnegans/features/assistant/presentation/providers/assistant_data_provider.dart';

final assistantChatProvider =
    NotifierProvider<AssistantChatController, ChatState>(
      AssistantChatController.new,
    );

class _PendingQuery {
  final String question;
  final AssistantDestination destination;
  final ChatMessage userMessage;
  String? payload;
  String context;

  _PendingQuery(this.question, this.destination)
    : context = destination.module.label,
      userMessage = ChatMessage(
        text: question,
        isUser: true,
        context: destination.module.label,
      );
}

class AssistantChatController extends Notifier<ChatState> {
  int _revision = 0;
  bool _busy = false;
  _PendingQuery? _failedQuery;
  Completer<void>? _cancellation;

  @override
  ChatState build() {
    ref.onDispose(() {
      _revision++;
      _cancelOperation();
      _failedQuery = null;
    });
    ref.listen(authProvider.select((auth) => auth.email), (prev, next) {
      if (prev != next) {
        _revision++;
        _cancelOperation();
        _failedQuery = null;
        // La operación anterior no puede publicar en la sesión nueva.
        state = ChatState(sending: _busy);
      }
    });
    return const ChatState();
  }

  void open() => state = state.copyWith(open: true, error: state.error);
  void close() => state = state.copyWith(open: false, error: state.error);

  void clear() {
    _revision++;
    _cancelOperation();
    _failedQuery = null;
    state = ChatState(open: state.open, sending: _busy);
  }

  void _cancelOperation() {
    final cancellation = _cancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
  }

  void _validateSession() {
    final auth = ref.read(authProvider);
    if (!auth.enabled || !auth.hasValidSession) {
      throw const AssistantException(AssistantErrorType.session, status: 401);
    }
    if (!auth.isAuthorized) {
      throw const AssistantException(
        AssistantErrorType.permission,
        status: 403,
      );
    }
  }

  Future<void> send(String text, AssistantDestination destination) async {
    if (_busy) return;
    final question = text.trim();
    final issue = ref.read(assistantQueryPlannerProvider).validate(question);
    if (issue != null) {
      state = state.copyWith(error: issue.message, canRetry: false);
      return;
    }
    try {
      _validateSession();
    } on AssistantException catch (error) {
      // No se vacía el editor ni se ofrece reintento de un fallo de acceso.
      state = state.copyWith(error: error.message, canRetry: false);
      return;
    }
    await _process(_PendingQuery(question, destination), addMessage: true);
  }

  Future<void> retry() async {
    final query = _failedQuery;
    if (_busy || query == null || !state.canRetry) return;
    await _process(query, addMessage: false);
  }

  bool _current(int ticket) => ref.mounted && ticket == _revision;

  void _registerError(int ticket, AssistantException error) {
    if (_current(ticket)) {
      state = state.copyWith(
        sending: true,
        error: error.message,
        canRetry: error.allowsRetry,
      );
    }
  }

  Future<void> _process(_PendingQuery query, {required bool addMessage}) async {
    if (_busy) return;
    final ticket = ++_revision;
    _busy = true;
    _cancellation = Completer<void>();
    _failedQuery = query;
    try {
      _validateSession();
      final messages = [...state.messages, if (addMessage) query.userMessage];
      // Guardar la pregunta antes de preparar el contexto: tampoco se pierde
      // si esa preparación falla. Reintentar reutiliza la misma burbuja.
      state = state.copyWith(
        sending: true,
        canRetry: false,
        messages: List.unmodifiable(
          messages.skip(messages.length > 39 ? messages.length - 39 : 0),
        ),
      );
      if (query.payload == null) {
        final context = await ref.read(prepareAiContextProvider)(
          query.destination,
          query.question,
        );
        if (!_current(ticket)) return;
        query.payload = ref
            .read(assistantPromptComposerProvider)
            .compose(query.question, context);
        query.context = assistantContextLabel(context);
      }
      if (!_current(ticket)) return;
      _validateSession();
      // Conservar el contexto de la consulta fallida aun si se navega a otro
      // módulo/período. Nunca enviar el historial ni errores como contexto.
      final response = await ref
          .read(assistantRepositoryProvider)
          .ask(query.payload!, cancellation: _cancellation!.future);
      if (!_current(ticket)) return;
      _validateSession();
      _failedQuery = null;
      state = state.copyWith(
        sending: true,
        canRetry: false,
        messages: List.unmodifiable([
          ...state.messages,
          ChatMessage(text: response, isUser: false, context: query.context),
        ]),
      );
    } on AssistantException catch (error) {
      _registerError(ticket, error);
    } on TimeoutException {
      _registerError(
        ticket,
        const AssistantException(AssistantErrorType.connection),
      );
    } on AssistantQueryException catch (error) {
      if (_current(ticket)) {
        state = state.copyWith(
          sending: true,
          error: error.message,
          canRetry: false,
        );
      }
    } catch (_) {
      _registerError(
        ticket,
        const AssistantException(AssistantErrorType.unknown),
      );
    } finally {
      _cancelOperation();
      _cancellation = null;
      _busy = false;
      if (ref.mounted) {
        state = state.copyWith(sending: false, error: state.error);
      }
    }
  }
}
