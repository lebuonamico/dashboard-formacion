import 'dart:async';

import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_context.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/chat_message.dart';
import 'package:app_finnegans/features/assistant/presentation/assistant_labels.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_providers.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_repository_provider.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/features/assistant/presentation/providers/assistant_providers.dart';

/// Trimmed before adding a question: with it and its answer, 40 at most.
const _maxMessagesBeforeQuestion = 39;

const _keep = Object();

class ChatState {
  final bool open;
  final bool sending;
  final List<ChatMessage> messages;
  final String? error;
  final bool canRetry;

  ChatState({
    this.open = false,
    this.sending = false,
    List<ChatMessage> messages = const [],
    this.error,
    this.canRetry = false,
  }) : messages = List.unmodifiable(messages);

  /// [error] is kept unless it is passed, also as `null`.
  ChatState copyWith({
    bool? open,
    bool? sending,
    List<ChatMessage>? messages,
    Object? error = _keep,
    bool? canRetry,
  }) => ChatState(
    open: open ?? this.open,
    sending: sending ?? this.sending,
    messages: messages ?? this.messages,
    error: identical(error, _keep) ? this.error : error as String?,
    canRetry: canRetry ?? this.canRetry,
  );
}

final assistantChatProvider =
    NotifierProvider<AssistantChatNotifier, ChatState>(
      AssistantChatNotifier.new,
    );

class _PendingQuery {
  final String question;
  final AssistantDestination destination;
  final ChatMessage userMessage;
  final String? payload;
  final String context;

  _PendingQuery(this.question, this.destination)
    : payload = null,
      context = destination.module.label,
      userMessage = ChatMessage(
        text: question,
        isUser: true,
        context: destination.module.label,
      );

  const _PendingQuery._(
    this.question,
    this.destination,
    this.userMessage,
    this.payload,
    this.context,
  );

  /// The same question, ready to send again without rebuilding the context.
  _PendingQuery withPayload(String payload, String context) =>
      _PendingQuery._(question, destination, userMessage, payload, context);
}

/// One query at a time. A failed query is kept, with the context it was
/// built with, so that retrying sends the same message.
class AssistantChatNotifier extends Notifier<ChatState> {
  int _revision = 0;
  _PendingQuery? _failedQuery;
  Completer<void>? _cancellation;

  @override
  ChatState build() {
    ref.onDispose(_discardPending);
    ref.listen(authProvider.select((auth) => auth.email), (previous, next) {
      if (previous != next) {
        _discardPending();
        // The previous operation cannot publish in the new session.
        state = ChatState(sending: state.sending);
      }
    });
    return ChatState();
  }

  void open() => state = state.copyWith(open: true);

  void close() => state = state.copyWith(open: false);

  void clear() {
    _discardPending();
    state = ChatState(open: state.open, sending: state.sending);
  }

  Future<void> send(String text, AssistantDestination destination) async {
    if (state.sending) return;
    final question = text.trim();
    final issue = ref.read(assistantQueryPlannerProvider).validate(question);
    if (issue != null) {
      state = state.copyWith(error: issue.message, canRetry: false);
      return;
    }
    try {
      _validateSession();
    } on AssistantException catch (error) {
      // Neither the editor is cleared nor an access failure retried.
      state = state.copyWith(error: error.message, canRetry: false);
      return;
    }
    await _process(_PendingQuery(question, destination), addMessage: true);
  }

  Future<void> retry() async {
    final query = _failedQuery;
    if (state.sending || query == null || !state.canRetry) return;
    await _process(query, addMessage: false);
  }

  void _discardPending() {
    _revision++;
    _cancelOperation();
    _failedQuery = null;
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

  bool _current(int ticket) => ref.mounted && ticket == _revision;

  /// Runs only when sending, with the data and the period the screens show.
  Future<AssistantContext> _prepareContext(_PendingQuery query) {
    final plan = ref
        .read(assistantQueryPlannerProvider)
        .plan(
          query.question,
          query.destination,
          ref.read(periodFilterProvider),
        );
    return ref
        .read(assistantContextBuilderProvider)
        .build(
          plan,
          dynamic: ref.read(aiRealContextProvider),
          loadData: () => ref.read(assistantDataProvider.future),
        )
        .timeout(const Duration(seconds: 30));
  }

  void _showError(int ticket, String message, {required bool canRetry}) {
    if (_current(ticket)) {
      state = state.copyWith(sending: true, error: message, canRetry: canRetry);
    }
  }

  Future<void> _process(_PendingQuery query, {required bool addMessage}) async {
    final ticket = ++_revision;
    final cancellation = _cancellation = Completer<void>();
    _failedQuery = query;
    try {
      _validateSession();
      final messages = [...state.messages, if (addMessage) query.userMessage];
      // The question is kept before preparing the context, so it is not lost
      // if that fails. A retry reuses the same bubble.
      state = state.copyWith(
        sending: true,
        error: null,
        canRetry: false,
        messages: messages
            .skip(
              messages.length > _maxMessagesBeforeQuestion
                  ? messages.length - _maxMessagesBeforeQuestion
                  : 0,
            )
            .toList(),
      );
      var pending = query;
      if (pending.payload == null) {
        final context = await _prepareContext(pending);
        if (!_current(ticket)) return;
        pending = pending.withPayload(
          ref
              .read(assistantPromptComposerProvider)
              .compose(pending.question, context),
          assistantContextLabel(context),
        );
        _failedQuery = pending;
      }
      _validateSession();
      // The failed query keeps its context even after moving to another
      // module or period. The history and errors are never sent.
      final response = await ref
          .read(assistantRepositoryProvider)
          .ask(pending.payload!, cancellation: cancellation.future);
      if (!_current(ticket)) return;
      _validateSession();
      _failedQuery = null;
      state = state.copyWith(
        sending: true,
        error: null,
        canRetry: false,
        messages: [
          ...state.messages,
          ChatMessage(text: response, isUser: false, context: pending.context),
        ],
      );
    } on AssistantException catch (error) {
      _showError(ticket, error.message, canRetry: error.allowsRetry);
    } on AssistantQueryException catch (error) {
      _showError(ticket, error.message, canRetry: false);
    } on TimeoutException {
      const error = AssistantException(AssistantErrorType.connection);
      _showError(ticket, error.message, canRetry: error.allowsRetry);
    } catch (_) {
      const error = AssistantException(AssistantErrorType.unknown);
      _showError(ticket, error.message, canRetry: error.allowsRetry);
    } finally {
      _cancelOperation();
      if (identical(_cancellation, cancellation)) _cancellation = null;
      if (ref.mounted) state = state.copyWith(sending: false);
    }
  }
}
