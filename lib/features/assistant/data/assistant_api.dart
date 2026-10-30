import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/features/assistant/domain/assistant_context_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AssistantErrorType {
  temporary,
  limit,
  connection,
  session,
  permission,
  unknown,
}

class AssistantException implements Exception {
  final String message;
  final int? status;
  final AssistantErrorType type;
  // Solo códigos conocidos para diagnóstico; nunca se guarda el cuerpo crudo.
  final String? code;
  const AssistantException(
    this.message, {
    this.status,
    this.type = AssistantErrorType.unknown,
    this.code,
  });

  static const temporaryMessage =
      'El servicio de IA está experimentando una dificultad temporal. Tu pregunta se conservó y podés volver a intentarlo en unos momentos.';
  static const limitMessage =
      'El asistente alcanzó temporalmente su límite de consultas. Intentá nuevamente más tarde.';
  static const connectionMessage =
      'No pudimos completar la conexión. Revisá tu conexión a Internet e intentá nuevamente.';
  static const sessionMessage =
      'Tu sesión venció. Volvé a iniciar sesión para continuar utilizando el asistente.';
  static const permissionMessage =
      'No tenés permisos para utilizar el asistente. Si creés que es un error, consultá con el administrador.';
  static const unknownMessage =
      'No pudimos completar tu consulta en este momento. Podés volver a intentarlo.';

  bool get allowsRetry =>
      status != 401 &&
      status != 403 &&
      type != AssistantErrorType.session &&
      type != AssistantErrorType.permission;

  factory AssistantException.http(int status, {Object? details}) {
    const codes = {
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
    String? code;
    if (body is Map) {
      final error = body['error'];
      for (final candidate in [
        if (error is Map) error['status'],
        if (error is Map) error['code'],
        body['status'],
        body['code'],
      ]) {
        if (candidate is String && codes.contains(candidate)) {
          code = candidate;
          break;
        }
      }
    }
    // Los estados de nuestra sesión tienen prioridad. Un error de credenciales
    // del proveedor dentro de un 502 no se presenta como sesión vencida.
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
    final message = switch (type) {
      AssistantErrorType.temporary => temporaryMessage,
      AssistantErrorType.limit => limitMessage,
      AssistantErrorType.connection => connectionMessage,
      AssistantErrorType.session => sessionMessage,
      AssistantErrorType.permission => permissionMessage,
      AssistantErrorType.unknown => unknownMessage,
    };
    return AssistantException(message, status: status, type: type, code: code);
  }
}

/// Usa el cliente compartido: functions.invoke adjunta la sesión de Supabase.
/// No conoce la clave ni el endpoint de Gemini. No realiza reintentos.
class AssistantApi {
  final SupabaseClient? client;
  final Duration timeout;

  AssistantApi(this.client, {this.timeout = const Duration(seconds: 40)});

  Future<String> query(String message, {Future<void>? cancellation}) async {
    final supabase = client;
    if (supabase == null ||
        supabase.auth.currentSession == null ||
        supabase.auth.currentSession!.isExpired) {
      throw AssistantException.http(401);
    }
    // Defensa local; el endpoint también debe imponer sus propios límites.
    if (message.trim().isEmpty ||
        message.length > AssistantContextService.maxMessage ||
        utf8.encode(message).length > AssistantContextService.maxMessage * 4) {
      throw const AssistantException(AssistantException.unknownMessage);
    }
    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    if (cancellation != null) {
      unawaited(cancellation.then((_) => cancel()));
    }
    try {
      final response = await supabase.functions
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
        throw AssistantException.http(response.status, details: response.data);
      }
      final data = response.data;
      final responseBody = data is Map ? data['respuesta'] : null;
      if (responseBody is! String ||
          responseBody.trim().isEmpty ||
          responseBody.length > 16000) {
        throw const AssistantException(AssistantException.unknownMessage);
      }
      return responseBody.trim();
    } on FunctionException catch (error) {
      throw AssistantException.http(error.status, details: error.details);
    } on TimeoutException {
      throw const AssistantException(
        AssistantException.connectionMessage,
        type: AssistantErrorType.connection,
      );
    } on AssistantException {
      rethrow;
    } catch (_) {
      // Ni mensajes internos, cuerpos, tokens ni stack traces al navegador.
      throw const AssistantException(AssistantException.unknownMessage);
    } finally {
      cancel();
    }
  }
}
