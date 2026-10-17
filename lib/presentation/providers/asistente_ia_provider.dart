import 'dart:async';

import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/data/asistente_ia_api.dart';
import 'package:app_finnegans/domain/modelos/mensaje_chat.dart';
import 'package:app_finnegans/domain/servicios/asistente_contexto_service.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/asistente_datos_provider.dart';

export 'package:app_finnegans/presentation/providers/asistente_datos_provider.dart';

final asistenteIaApiProvider = Provider<AsistenteIaApi>(
  (ref) => AsistenteIaApi(
    SupabaseConfig.enabled ? ref.watch(supabaseClientProvider) : null,
  ),
);

final asistenteChatProvider =
    NotifierProvider<AsistenteChatController, EstadoChat>(
      AsistenteChatController.new,
    );

class AsistenteChatController extends Notifier<EstadoChat> {
  int _revision = 0;
  bool _ocupado = false;

  @override
  EstadoChat build() {
    ref.listen(authControllerProvider.select((auth) => auth.email), (
      prev,
      next,
    ) {
      if (prev != next) {
        _revision++;
        state = const EstadoChat();
      }
    });
    return const EstadoChat();
  }

  void abrir() => state = state.copyWith(abierto: true);
  void cerrar() => state = state.copyWith(abierto: false, error: state.error);

  void limpiar() {
    _revision++;
    state = EstadoChat(abierto: state.abierto, enviando: _ocupado);
  }

  Future<void> enviar(String texto, DestinoAsistente destino) async {
    if (_ocupado) return;
    final pregunta = texto.trim();
    final service = ref.read(asistenteContextoServiceProvider);
    final validacion = service.validarPregunta(pregunta);
    if (validacion != null) {
      state = state.copyWith(error: validacion);
      return;
    }
    final auth = ref.read(authControllerProvider);
    if (!auth.enabled || !auth.isAuthorized) {
      state = state.copyWith(
        error: !auth.enabled
            ? 'La IA requiere el modo Supabase y una sesión autorizada. No hay respuestas simuladas.'
            : !auth.hasValidSession
            ? 'No hay una sesión vigente. Iniciá sesión nuevamente para consultar la IA.'
            : 'Tu sesión no está autorizada para consultar la IA.',
      );
      return;
    }
    final ticket = ++_revision;
    _ocupado = true;
    try {
      state = state.copyWith(enviando: true);
      final contexto = await ref.read(prepararContextoIaProvider)(
        destino,
        pregunta,
      );
      final mensaje = service.componerMensaje(pregunta, contexto);
      if (!ref.mounted || ticket != _revision) return;
      final authActual = ref.read(authControllerProvider);
      if (!authActual.isAuthorized) {
        if (!authActual.hasValidSession) {
          throw const AsistenteIaException(
            'La sesión dejó de estar vigente. Iniciá sesión nuevamente.',
            status: 401,
          );
        }
        throw AsistenteIaException.http(403);
      }
      final mensajes = [
        ...state.mensajes,
        MensajeChat(
          texto: pregunta,
          esUsuario: true,
          contexto: contexto.etiqueta,
        ),
      ];
      // Acotado y solo en memoria, nunca SharedPreferences ni base de datos.
      state = state.copyWith(
        enviando: true,
        mensajes: List.unmodifiable(
          mensajes.skip(mensajes.length > 39 ? mensajes.length - 39 : 0),
        ),
      );
      final respuesta = await ref
          .read(asistenteIaApiProvider)
          .consultar(mensaje);
      if (!ref.mounted || ticket != _revision) return;
      state = state.copyWith(
        enviando: true,
        mensajes: List.unmodifiable([
          ...state.mensajes,
          MensajeChat(
            texto: respuesta,
            esUsuario: false,
            contexto: contexto.etiqueta,
          ),
        ]),
      );
    } on FormatException catch (error) {
      if (ref.mounted && ticket == _revision) {
        state = state.copyWith(enviando: true, error: error.message);
      }
    } on AsistenteIaException catch (error) {
      if (ref.mounted && ticket == _revision) {
        state = state.copyWith(enviando: true, error: error.mensaje);
      }
    } catch (_) {
      if (ref.mounted && ticket == _revision) {
        state = state.copyWith(
          enviando: true,
          error: 'No se pudo completar la consulta de IA. Intentá más tarde.',
        );
      }
    } finally {
      _ocupado = false;
      if (ref.mounted) {
        state = state.copyWith(enviando: false, error: state.error);
      }
    }
  }
}
