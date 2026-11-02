import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/features/assistant/domain/assistant_prompt_composer.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _knownCodes = {
  'RESOURCE_EXHAUSTED',
  'UNAVAILABLE',
  'INTERNAL',
  'DEADLINE_EXCEEDED',
  'INVALID_ARGUMENT',
  'FAILED_PRECONDITION',
  'UNAUTHENTICATED',
  'PERMISSION_DENIED',
  'NOT_FOUND',
  'BOOT_ERROR',
  'WORKER_LIMIT',
  'WORKER_RESOURCE_LIMIT',
};

AssistantException _fromHttp(int status, {Object? details}) {
  Object? body = details;
  if (body is String) {
    if (body.length > 16000) {
      body = null;
    } else {
      try {
        body = jsonDecode(body);
      } on FormatException {
        body = null;
      }
    }
  }
  final error = body is Map ? body['error'] : null;
  final code = body is Map
      ? [
          if (error is Map) error['status'],
          if (error is Map) error['code'],
          body['status'],
          body['code'],
        ].whereType<String>().where(_knownCodes.contains).firstOrNull
      : null;
  // Our own session statuses take precedence: a provider credentials error
  // inside a 502 is not shown as an expired session.
  final type = switch (status) {
    401 => AssistantErrorType.session,
    403 => AssistantErrorType.permission,
    429 => AssistantErrorType.limit,
    0 || 408 || 504 => AssistantErrorType.connection,
    _ when code == 'RESOURCE_EXHAUSTED' => AssistantErrorType.limit,
    _ when code == 'DEADLINE_EXCEEDED' => AssistantErrorType.connection,
    502 || 503 when code == 'UNAVAILABLE' => AssistantErrorType.temporary,
    _ => AssistantErrorType.unknown,
  };
  return AssistantException(type, status: status, code: code);
}

/// Uses the shared client, so functions.invoke attaches the Supabase session.
/// It knows neither the Gemini key nor its endpoint.
class SupabaseAssistantRepository implements AssistantRepository {
  final SupabaseClient _client;
  final Duration timeout;

  SupabaseAssistantRepository(
    this._client, {
    this.timeout = const Duration(seconds: 40),
  });

  @override
  Future<String> ask(String message, {Future<void>? cancellation}) async {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) throw _fromHttp(401);
    // Local defense; the endpoint enforces its own limits too.
    if (message.trim().isEmpty ||
        message.length > AssistantPromptComposer.maxMessage ||
        utf8.encode(message).length > AssistantPromptComposer.maxMessage * 4) {
      throw const AssistantException(AssistantErrorType.unknown);
    }
    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    if (cancellation != null) {
      unawaited(cancellation.then((_) => cancel()));
    }
    try {
      final response = await _client.functions
          .invoke(
            'asistente-ia',
            body: {'mensaje': message},
            abortSignal: abort.future,
          )
          .timeout(
            timeout,
            onTimeout: () {
              cancel();
              throw TimeoutException('assistant_timeout');
            },
          );
      if (response.status < 200 || response.status >= 300) {
        throw _fromHttp(response.status, details: response.data);
      }
      final data = response.data;
      final answer = data is Map ? data['respuesta'] : null;
      if (answer is! String || answer.trim().isEmpty || answer.length > 16000) {
        throw const AssistantException(AssistantErrorType.unknown);
      }
      return answer.trim();
    } on FunctionException catch (error) {
      throw _fromHttp(error.status, details: error.details);
    } on TimeoutException {
      throw const AssistantException(AssistantErrorType.connection);
    } on AssistantException {
      rethrow;
    } catch (_) {
      // No internal messages, bodies, tokens or stack traces reach the browser.
      throw const AssistantException(AssistantErrorType.unknown);
    } finally {
      cancel();
    }
  }
}
