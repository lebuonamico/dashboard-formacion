import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/domain/servicios/asistente_contexto_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TipoErrorAsistente {
  temporal,
  limite,
  conexion,
  sesion,
  permiso,
  desconocido,
}

class AsistenteIaException implements Exception {
  final String mensaje;
  final int? status;
  final TipoErrorAsistente tipo;
  // Solo códigos conocidos para diagnóstico; nunca se guarda el cuerpo crudo.
  final String? codigo;
  const AsistenteIaException(
    this.mensaje, {
    this.status,
    this.tipo = TipoErrorAsistente.desconocido,
    this.codigo,
  });

  static const mensajeTemporal =
      'El servicio de IA está experimentando una dificultad temporal. Tu pregunta se conservó y podés volver a intentarlo en unos momentos.';
  static const mensajeLimite =
      'El asistente alcanzó temporalmente su límite de consultas. Intentá nuevamente más tarde.';
  static const mensajeConexion =
      'No pudimos completar la conexión. Revisá tu conexión a Internet e intentá nuevamente.';
  static const mensajeSesion =
      'Tu sesión venció. Volvé a iniciar sesión para continuar utilizando el asistente.';
  static const mensajePermiso =
      'No tenés permisos para utilizar el asistente. Si creés que es un error, consultá con el administrador.';
  static const mensajeDesconocido =
      'No pudimos completar tu consulta en este momento. Podés volver a intentarlo.';

  bool get permiteReintentar =>
      status != 401 &&
      status != 403 &&
      tipo != TipoErrorAsistente.sesion &&
      tipo != TipoErrorAsistente.permiso;

  factory AsistenteIaException.http(int status, {Object? details}) {
    const codigos = {
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
    Object? cuerpo = details;
    if (cuerpo is String) {
      if (cuerpo.length > 16000) {
        cuerpo = null;
      } else {
        try {
          cuerpo = jsonDecode(cuerpo);
        } on FormatException {
          cuerpo = null;
        }
      }
    }
    String? codigo;
    if (cuerpo is Map) {
      final error = cuerpo['error'];
      for (final candidato in [
        if (error is Map) error['status'],
        if (error is Map) error['code'],
        cuerpo['status'],
        cuerpo['code'],
      ]) {
        if (candidato is String && codigos.contains(candidato)) {
          codigo = candidato;
          break;
        }
      }
    }
    // Los estados de nuestra sesión tienen prioridad. Un error de credenciales
    // del proveedor dentro de un 502 no se presenta como sesión vencida.
    final tipo = switch (status) {
      401 => TipoErrorAsistente.sesion,
      403 => TipoErrorAsistente.permiso,
      429 => TipoErrorAsistente.limite,
      0 || 408 || 504 => TipoErrorAsistente.conexion,
      _ when codigo == 'RESOURCE_EXHAUSTED' => TipoErrorAsistente.limite,
      _ when codigo == 'DEADLINE_EXCEEDED' => TipoErrorAsistente.conexion,
      502 || 503 when codigo == 'UNAVAILABLE' => TipoErrorAsistente.temporal,
      _ => TipoErrorAsistente.desconocido,
    };
    final mensaje = switch (tipo) {
      TipoErrorAsistente.temporal => mensajeTemporal,
      TipoErrorAsistente.limite => mensajeLimite,
      TipoErrorAsistente.conexion => mensajeConexion,
      TipoErrorAsistente.sesion => mensajeSesion,
      TipoErrorAsistente.permiso => mensajePermiso,
      TipoErrorAsistente.desconocido => mensajeDesconocido,
    };
    return AsistenteIaException(
      mensaje,
      status: status,
      tipo: tipo,
      codigo: codigo,
    );
  }
}

/// Usa el cliente compartido: functions.invoke adjunta la sesión de Supabase.
/// No conoce la clave ni el endpoint de Gemini. No realiza reintentos.
class AsistenteIaApi {
  final SupabaseClient? client;
  final Duration timeout;

  AsistenteIaApi(this.client, {this.timeout = const Duration(seconds: 40)});

  Future<String> consultar(String mensaje, {Future<void>? cancelacion}) async {
    final supabase = client;
    if (supabase == null ||
        supabase.auth.currentSession == null ||
        supabase.auth.currentSession!.isExpired) {
      throw AsistenteIaException.http(401);
    }
    // Defensa local; el endpoint también debe imponer sus propios límites.
    if (mensaje.trim().isEmpty ||
        mensaje.length > AsistenteContextoService.maxMensaje ||
        utf8.encode(mensaje).length > AsistenteContextoService.maxMensaje * 4) {
      throw const AsistenteIaException(AsistenteIaException.mensajeDesconocido);
    }
    final abortar = Completer<void>();
    void cancelar() {
      if (!abortar.isCompleted) abortar.complete();
    }

    if (cancelacion != null) {
      unawaited(cancelacion.then((_) => cancelar()));
    }
    try {
      final response = await supabase.functions
          .invoke(
            'asistente-ia',
            body: {'mensaje': mensaje},
            abortSignal: abortar.future,
          )
          .timeout(
            timeout,
            onTimeout: () {
              cancelar();
              throw TimeoutException('assistant_timeout');
            },
          );
      if (response.status < 200 || response.status >= 300) {
        throw AsistenteIaException.http(
          response.status,
          details: response.data,
        );
      }
      final data = response.data;
      final respuesta = data is Map ? data['respuesta'] : null;
      if (respuesta is! String ||
          respuesta.trim().isEmpty ||
          respuesta.length > 16000) {
        throw const AsistenteIaException(
          AsistenteIaException.mensajeDesconocido,
        );
      }
      return respuesta.trim();
    } on FunctionException catch (error) {
      throw AsistenteIaException.http(error.status, details: error.details);
    } on TimeoutException {
      throw const AsistenteIaException(
        AsistenteIaException.mensajeConexion,
        tipo: TipoErrorAsistente.conexion,
      );
    } on AsistenteIaException {
      rethrow;
    } catch (_) {
      // Ni mensajes internos, cuerpos, tokens ni stack traces al navegador.
      throw const AsistenteIaException(AsistenteIaException.mensajeDesconocido);
    } finally {
      cancelar();
    }
  }
}
