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

class _ConsultaPendiente {
  final String pregunta;
  final DestinoAsistente destino;
  final MensajeChat mensajeUsuario;
  String? payload;
  String contexto;

  _ConsultaPendiente(this.pregunta, this.destino)
    : contexto = destino.modulo.etiqueta,
      mensajeUsuario = MensajeChat(
        texto: pregunta,
        esUsuario: true,
        contexto: destino.modulo.etiqueta,
      );
}

class AsistenteChatController extends Notifier<EstadoChat> {
  int _revision = 0;
  bool _ocupado = false;
  _ConsultaPendiente? _consultaFallida;
  Completer<void>? _cancelacion;

  @override
  EstadoChat build() {
    ref.onDispose(() {
      _revision++;
      _cancelarOperacion();
      _consultaFallida = null;
    });
    ref.listen(authControllerProvider.select((auth) => auth.email), (
      prev,
      next,
    ) {
      if (prev != next) {
        _revision++;
        _cancelarOperacion();
        _consultaFallida = null;
        // La operación anterior no puede publicar en la sesión nueva.
        state = EstadoChat(enviando: _ocupado);
      }
    });
    return const EstadoChat();
  }

  void abrir() => state = state.copyWith(abierto: true, error: state.error);
  void cerrar() => state = state.copyWith(abierto: false, error: state.error);

  void limpiar() {
    _revision++;
    _cancelarOperacion();
    _consultaFallida = null;
    state = EstadoChat(abierto: state.abierto, enviando: _ocupado);
  }

  void _cancelarOperacion() {
    final cancelacion = _cancelacion;
    if (cancelacion != null && !cancelacion.isCompleted) cancelacion.complete();
  }

  void _validarSesion() {
    final auth = ref.read(authControllerProvider);
    if (!auth.enabled || !auth.hasValidSession) {
      throw AsistenteIaException.http(401);
    }
    if (!auth.isAuthorized) throw AsistenteIaException.http(403);
  }

  Future<void> enviar(String texto, DestinoAsistente destino) async {
    if (_ocupado) return;
    final pregunta = texto.trim();
    final validacion = ref
        .read(asistenteContextoServiceProvider)
        .validarPregunta(pregunta);
    if (validacion != null) {
      state = state.copyWith(error: validacion, puedeReintentar: false);
      return;
    }
    try {
      _validarSesion();
    } on AsistenteIaException catch (error) {
      // No se vacía el editor ni se ofrece reintento de un fallo de acceso.
      state = state.copyWith(error: error.mensaje, puedeReintentar: false);
      return;
    }
    await _procesar(
      _ConsultaPendiente(pregunta, destino),
      agregarMensaje: true,
    );
  }

  Future<void> reintentar() async {
    final consulta = _consultaFallida;
    if (_ocupado || consulta == null || !state.puedeReintentar) return;
    await _procesar(consulta, agregarMensaje: false);
  }

  bool _vigente(int ticket) => ref.mounted && ticket == _revision;

  void _registrarError(int ticket, AsistenteIaException error) {
    if (_vigente(ticket)) {
      state = state.copyWith(
        enviando: true,
        error: error.mensaje,
        puedeReintentar: error.permiteReintentar,
      );
    }
  }

  Future<void> _procesar(
    _ConsultaPendiente consulta, {
    required bool agregarMensaje,
  }) async {
    if (_ocupado) return;
    final ticket = ++_revision;
    _ocupado = true;
    _cancelacion = Completer<void>();
    _consultaFallida = consulta;
    try {
      _validarSesion();
      final mensajes = [
        ...state.mensajes,
        if (agregarMensaje) consulta.mensajeUsuario,
      ];
      // Guardar la pregunta antes de preparar el contexto: tampoco se pierde
      // si esa preparación falla. Reintentar reutiliza la misma burbuja.
      state = state.copyWith(
        enviando: true,
        puedeReintentar: false,
        mensajes: List.unmodifiable(
          mensajes.skip(mensajes.length > 39 ? mensajes.length - 39 : 0),
        ),
      );
      if (consulta.payload == null) {
        final contexto = await ref.read(prepararContextoIaProvider)(
          consulta.destino,
          consulta.pregunta,
        );
        if (!_vigente(ticket)) return;
        consulta.payload = ref
            .read(asistenteContextoServiceProvider)
            .componerMensaje(consulta.pregunta, contexto);
        consulta.contexto = contexto.etiqueta;
      }
      if (!_vigente(ticket)) return;
      _validarSesion();
      // Conservar el contexto de la consulta fallida aun si se navega a otro
      // módulo/período. Nunca enviar el historial ni errores como contexto.
      final respuesta = await ref
          .read(asistenteIaApiProvider)
          .consultar(consulta.payload!, cancelacion: _cancelacion!.future);
      if (!_vigente(ticket)) return;
      _validarSesion();
      _consultaFallida = null;
      state = state.copyWith(
        enviando: true,
        puedeReintentar: false,
        mensajes: List.unmodifiable([
          ...state.mensajes,
          MensajeChat(
            texto: respuesta,
            esUsuario: false,
            contexto: consulta.contexto,
          ),
        ]),
      );
    } on AsistenteIaException catch (error) {
      _registrarError(ticket, error);
    } on TimeoutException {
      _registrarError(
        ticket,
        const AsistenteIaException(
          AsistenteIaException.mensajeConexion,
          tipo: TipoErrorAsistente.conexion,
        ),
      );
    } on FormatException catch (error) {
      // Solo validaciones redactadas por nuestro servicio; nunca propagar
      // mensajes arbitrarios de repositorios, Supabase o proveedores.
      final mensaje = switch (error.message) {
        'Indicá un mes válido entre 1 y 12.' => error.message,
        'La consulta supera el contexto disponible. Pedí menos períodos o precisá el equipo, área o curso.' =>
          error.message,
        _ => AsistenteIaException.mensajeDesconocido,
      };
      if (_vigente(ticket)) {
        state = state.copyWith(
          enviando: true,
          error: mensaje,
          puedeReintentar: mensaje == AsistenteIaException.mensajeDesconocido,
        );
      }
    } catch (_) {
      _registrarError(
        ticket,
        const AsistenteIaException(AsistenteIaException.mensajeDesconocido),
      );
    } finally {
      _cancelarOperacion();
      _cancelacion = null;
      _ocupado = false;
      if (ref.mounted) {
        state = state.copyWith(enviando: false, error: state.error);
      }
    }
  }
}
