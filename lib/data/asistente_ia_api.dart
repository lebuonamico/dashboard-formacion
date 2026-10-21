import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class AsistenteIaException implements Exception {
  final String mensaje;
  final int? status;
  const AsistenteIaException(this.mensaje, {this.status});

  static const _mensajesPorCodigo = {
    'RESOURCE_EXHAUSTED':
        'El servicio de IA informó un límite de uso o cuota. Esperá antes de volver a consultar',
    'INVALID_ARGUMENT':
        'El servicio de IA rechazó los parámetros o la configuración de la consulta',
    'FAILED_PRECONDITION':
        'El servicio de IA no puede procesar la consulta con la configuración actual',
    'UNAUTHENTICATED': 'El servicio de IA informó un fallo de autenticación',
    'PERMISSION_DENIED':
        'El servicio de IA informó que faltan permisos para la consulta',
    'NOT_FOUND': 'El servicio de IA no encontró el recurso solicitado',
    'UNAVAILABLE': 'El servicio de IA informó que no está disponible',
    'INTERNAL': 'El servicio de IA informó un error interno',
    'DEADLINE_EXCEEDED':
        'El servicio de IA agotó el tiempo de espera de la consulta',
    'BOOT_ERROR': 'La función de IA no pudo iniciarse en Supabase',
    'WORKER_LIMIT': 'La función de IA excedió los recursos de Supabase',
    'WORKER_RESOURCE_LIMIT':
        'La función de IA excedió los recursos de Supabase',
  };

  factory AsistenteIaException.http(int status, {Object? details}) {
    // Leer solo códigos conocidos; nunca mostrar mensajes crudos del servidor.
    Object? cuerpo = details;
    if (cuerpo is String && cuerpo.length <= 16000) {
      try {
        cuerpo = jsonDecode(cuerpo);
      } on FormatException {
        cuerpo = null;
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
        if (candidato is String && _mensajesPorCodigo.containsKey(candidato)) {
          codigo = candidato;
          break;
        }
      }
    }
    final mensaje =
        _mensajesPorCodigo[codigo] ??
        switch (status) {
          0 => 'No se pudo conectar con la IA. Revisá tu conexión',
          400 =>
            'El servicio de IA rechazó los datos o el formato de la consulta',
          401 =>
            'El servicio de IA rechazó la autenticación. Revisá tu sesión; si persiste, la configuración del servicio',
          403 => 'El servicio de IA rechazó el acceso a la consulta',
          404 => 'No se encontró la función o el recurso de IA solicitado',
          408 || 504 => 'El servicio de IA agotó el tiempo de espera',
          413 => 'La consulta supera el tamaño admitido por el servicio de IA',
          422 => 'El servicio de IA no pudo procesar los datos de la consulta',
          429 =>
            'El servicio de IA informó un límite de solicitudes o cuota. Esperá antes de volver a consultar',
          500 =>
            'El servicio de IA devolvió un error interno. No se pudo determinar la causa específica',
          502 => 'No se pudo obtener una respuesta válida del servicio de IA',
          503 =>
            'El servicio de IA no está disponible. No se pudo determinar la causa específica',
          546 => 'La función de IA excedió los recursos de Supabase',
          _ =>
            'No se pudo completar la consulta a la IA. No se pudo determinar la causa específica',
        };
    return AsistenteIaException(
      status == 0
          ? '$mensaje.'
          : '$mensaje (HTTP $status${codigo == null ? '' : ' · $codigo'}).',
      status: status,
    );
  }
}

/// Usa el cliente compartido: functions.invoke adjunta la sesión de Supabase.
/// No conoce la clave ni el endpoint de Gemini.
class AsistenteIaApi {
  final SupabaseClient? client;
  final Duration timeout;

  AsistenteIaApi(this.client, {this.timeout = const Duration(seconds: 40)});

  Future<String> consultar(String mensaje) async {
    final supabase = client;
    if (supabase == null) {
      throw const AsistenteIaException(
        'La IA requiere el modo Supabase y una sesión autorizada. El modo local no genera respuestas simuladas.',
      );
    }
    if (supabase.auth.currentSession == null) {
      throw const AsistenteIaException(
        'No hay una sesión iniciada. Iniciá sesión para consultar la IA.',
        status: 401,
      );
    }
    try {
      final response = await supabase.functions
          .invoke('asistente-ia', body: {'mensaje': mensaje})
          .timeout(timeout);
      if (response.status < 200 || response.status >= 300) {
        throw AsistenteIaException.http(
          response.status,
          details: response.data,
        );
      }
      final data = response.data;
      final respuesta = data is Map ? data['respuesta'] : null;
      if (respuesta is! String || respuesta.trim().isEmpty) {
        throw const AsistenteIaException(
          'La IA devolvió una respuesta inválida. Intentá más tarde.',
        );
      }
      if (respuesta.length > 16000) {
        throw const AsistenteIaException(
          'La respuesta supera el tamaño admitido por la aplicación. Pedí una respuesta más breve.',
        );
      }
      return respuesta.trim();
    } on FunctionException catch (error) {
      throw AsistenteIaException.http(error.status, details: error.details);
    } on TimeoutException {
      throw const AsistenteIaException(
        'La consulta tardó demasiado. No se reintentará automáticamente.',
      );
    } on AsistenteIaException {
      rethrow;
    } on FormatException {
      throw const AsistenteIaException(
        'El servicio de IA devolvió una respuesta con un formato inválido.',
      );
    } catch (_) {
      throw const AsistenteIaException(
        'Ocurrió un error inesperado al procesar la consulta de IA. Intentá más tarde.',
      );
    }
  }
}
