import 'dart:math' as math;

import 'package:app_finnegans/domain/modelos/mensaje_chat.dart';
import 'package:app_finnegans/domain/servicios/asistente_contexto_service.dart';
import 'package:app_finnegans/presentation/providers/asistente_ia_provider.dart';
import 'package:app_finnegans/presentation/widgets/asistente_mensaje.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tamaño del símbolo del botón flotante del asistente.
const double _tamanoSimbolo = 52;

/// Posición del botón y del panel dentro del área visible.
class DisposicionAsistente {
  /// Símbolo de [_tamanoSimbolo] más el borde de 2 px de cada lado.
  static const diametroBoton = 56.0;

  /// El badge de Netlify del deploy mide ~170 px de ancho y está a ~16 px de
  /// la esquina inferior derecha. El botón va a su izquierda, centrado en su
  /// misma línea, dentro de la franja libre que dejan las pantallas debajo del
  /// paginado ([margenInferiorPaginacion]).
  static const _derechaJuntoAlBadge = 200.0;
  static const _baseJuntoAlBadge = 8.0;

  final double margen;
  final double derechaBoton;
  final double baseBoton;
  final double basePanel;

  const DisposicionAsistente._(
    this.margen,
    this.derechaBoton,
    this.baseBoton,
    this.basePanel,
  );

  factory DisposicionAsistente.para(Size disponible) {
    final margen = disponible.width < 600 ? 12.0 : 20.0;
    final despeje = math.min(
      (disponible.height * .1).clamp(56.0, 96.0),
      disponible.height * .2,
    );
    // En ventanas muy angostas no puede quedar fuera de la pantalla.
    final derechaBoton = math.max(
      margen,
      math.min(
        _derechaJuntoAlBadge,
        disponible.width - diametroBoton - margen,
      ),
    );
    return DisposicionAsistente._(
      margen,
      derechaBoton,
      _baseJuntoAlBadge,
      despeje,
    );
  }
}

/// Copiloto del AppShell autenticado; su estado vive al cambiar de módulo.
class AsistenteChat extends ConsumerStatefulWidget {
  const AsistenteChat({super.key});

  @override
  ConsumerState<AsistenteChat> createState() => _AsistenteChatState();
}

class _AsistenteChatState extends ConsumerState<AsistenteChat> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  double _offsetGuardado = 0;
  MensajeChat? _ultimoAlMinimizar;
  String? _errorAlMinimizar;
  static const _tinta = Color(0xFF17243D);
  static const _violeta = Color(0xFF6451D8);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _offsetGuardado = _scroll.offset);
  }

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _enviar(DestinoAsistente destino) async {
    if (ref.read(asistenteChatProvider).enviando) return;
    final valor = _texto.value;
    if (valor.text.trim().isEmpty ||
        (valor.composing.isValid && !valor.composing.isCollapsed)) {
      return;
    }
    final envio = ref
        .read(asistenteChatProvider.notifier)
        .enviar(valor.text, destino);
    if (ref.read(asistenteChatProvider).enviando) _texto.clear();
    // No tocar el borrador ni la conexión de entrada al recibir una respuesta.
    await envio;
  }

  KeyEventResult _teclaEditor(KeyEvent event, DestinoAsistente destino) {
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final teclado = HardwareKeyboard.instance;
    if (teclado.isShiftPressed ||
        teclado.isControlPressed ||
        teclado.isAltPressed ||
        teclado.isMetaPressed ||
        (_texto.value.composing.isValid &&
            !_texto.value.composing.isCollapsed)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) _enviar(destino);
    // Consumir solo Enter: también durante la espera, sin borrar el borrador.
    return KeyEventResult.handled;
  }

  void _minimizar() {
    final estado = ref.read(asistenteChatProvider);
    _ultimoAlMinimizar = estado.mensajes.lastOrNull;
    _errorAlMinimizar = estado.error;
    ref.read(asistenteChatProvider.notifier).cerrar();
  }

  Future<void> _limpiarConversacion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.delete_outline_rounded, color: _violeta),
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
            style: FilledButton.styleFrom(backgroundColor: _violeta),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpiar conversación'),
          ),
        ],
      ),
    );
    if (!mounted || confirmado != true) return;
    ref.read(asistenteChatProvider.notifier).limpiar();
    _texto.clear();
    _ultimoAlMinimizar = null;
    _errorAlMinimizar = null;
  }

  Future<void> _copiarConversacion() async {
    final mensajes = ref.read(asistenteChatProvider).mensajes;
    if (mensajes.isEmpty) return;
    final conversacion = mensajes
        .map((m) => '${m.esUsuario ? 'Usuario' : 'Asistente'}:\n${m.texto}')
        .join('\n\n');
    String aviso;
    try {
      await Clipboard.setData(ClipboardData(text: conversacion));
      aviso = 'Conversación copiada';
    } catch (_) {
      aviso = 'No se pudo copiar. Revisá los permisos del portapapeles.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(aviso),
        duration: const Duration(seconds: 2),
        backgroundColor: _tinta,
      ),
    );
  }

  void _actualizarScroll(EstadoChat? anterior, EstadoChat siguiente) {
    if (!siguiente.abierto) return;
    final ultimo = siguiente.mensajes.lastOrNull;
    final cambioMensaje = !identical(anterior?.mensajes.lastOrNull, ultimo);
    final abriendo = anterior?.abierto != true;
    final respuestaPendiente =
        abriendo && !identical(_ultimoAlMinimizar, ultimo);
    final siguiendo = !_scroll.hasClients || _scroll.position.extentAfter < 72;
    final mostrarMensaje =
        ultimo != null &&
        (respuestaPendiente ||
            (cambioMensaje && (ultimo.esUsuario || siguiendo)));
    final mostrarError =
        siguiente.error != null &&
        ((abriendo && _errorAlMinimizar != siguiente.error) ||
            (anterior?.error != siguiente.error && siguiendo));
    if (!abriendo && !cambioMensaje && !mostrarError) return;
    final duracion = _movimiento(context, 180);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (mostrarMensaje) {
        if (!identical(
          ref.read(asistenteChatProvider).mensajes.lastOrNull,
          ultimo,
        )) {
          return;
        }
        if (ultimo.esUsuario) {
          if (duracion == Duration.zero) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          } else {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: duracion,
              curve: Curves.easeOut,
            );
          }
          return;
        }
        final render = GlobalObjectKey(
          ultimo,
        ).currentContext?.findRenderObject();
        if (render != null) {
          _scroll.position.ensureVisible(
            render,
            alignment: 0,
            duration: duracion,
            curve: Curves.easeOut,
          );
        }
      } else if (mostrarError) {
        if (duracion == Duration.zero) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        } else {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: duracion,
            curve: Curves.easeOut,
          );
        }
      } else if (abriendo || ultimo == null) {
        _scroll.jumpTo(
          ultimo == null
              ? 0
              : _offsetGuardado.clamp(0, _scroll.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(asistenteChatProvider);
    final real = ref.watch(iaContextoRealProvider);
    final uri = GoRouterState.of(context).uri;
    final destino = DestinoAsistente.desdeUri(uri);
    ref.listen(asistenteChatProvider, _actualizarScroll);
    final duracion = _movimiento(context, 220);

    return LayoutBuilder(
      builder: (context, constraints) {
        final disposicion = DisposicionAsistente.para(constraints.biggest);
        final margen = disposicion.margen;
        final ancho = math.max(
          0.0,
          math.min(480.0, constraints.maxWidth - margen * 2),
        );
        final alto = math.max(
          0.0,
          math.min(
            740.0,
            constraints.maxHeight - disposicion.basePanel - margen,
          ),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Un solo panel montado evita reanexar controladores al minimizar.
            Positioned(
              right: margen,
              bottom: disposicion.basePanel,
              width: ancho,
              height: alto,
              child: IgnorePointer(
                ignoring: !estado.abierto,
                child: ExcludeFocus(
                  excluding: !estado.abierto,
                  child: ExcludeSemantics(
                    excluding: !estado.abierto,
                    child: AnimatedSlide(
                      offset: estado.abierto
                          ? Offset.zero
                          : const Offset(.015, .035),
                      duration: duracion,
                      curve: Curves.easeOutCubic,
                      child: AnimatedScale(
                        scale: estado.abierto ? 1 : .96,
                        alignment: Alignment.bottomRight,
                        duration: duracion,
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: estado.abierto ? 1 : 0,
                          duration: duracion,
                          child: TickerMode(
                            enabled: estado.abierto,
                            child: _panel(estado, destino, real, ancho, alto),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: disposicion.derechaBoton,
              bottom: disposicion.baseBoton,
              child: IgnorePointer(
                ignoring: estado.abierto,
                child: ExcludeFocus(
                  excluding: estado.abierto,
                  child: ExcludeSemantics(
                    excluding: estado.abierto,
                    child: AnimatedScale(
                      scale: estado.abierto ? .8 : 1,
                      duration: duracion,
                      child: AnimatedOpacity(
                        opacity: estado.abierto ? 0 : 1,
                        duration: duracion,
                        child: _BotonCopiloto(
                          onPressed: ref
                              .read(asistenteChatProvider.notifier)
                              .abrir,
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
    EstadoChat estado,
    DestinoAsistente destino,
    bool real,
    double ancho,
    double alto,
  ) {
    final compacto = alto < 430;
    final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cabecera = _encabezado(estado, ancho, compacto);
    final conversacion = _conversacion(estado, real);
    final editor = _editor(estado, destino, compacto);
    return Container(
      key: const Key('asistente_panel'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE0E5F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26182C58),
            blurRadius: 44,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x145E4ED1),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: alto < 270 * escala
            // Con teclado y muy poca altura, todo el panel sigue siendo accesible.
            ? SingleChildScrollView(
                primary: false,
                child: Column(
                  children: [
                    cabecera,
                    SizedBox(
                      height: math.max(130, alto * .55),
                      child: conversacion,
                    ),
                    editor,
                  ],
                ),
              )
            : Column(
                children: [
                  cabecera,
                  Expanded(child: conversacion),
                  editor,
                ],
              ),
      ),
    );
  }

  Widget _encabezado(EstadoChat estado, double ancho, bool compacto) {
    final dosFilas =
        !compacto &&
        (ancho < 430 || MediaQuery.textScalerOf(context).scale(16) > 20);
    final acciones = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _accionHeader(
          Icons.copy_outlined,
          'Copiar conversación',
          estado.mensajes.isEmpty ? null : _copiarConversacion,
        ),
        _accionHeader(
          Icons.delete_outline_rounded,
          'Limpiar conversación',
          _limpiarConversacion,
        ),
        _accionHeader(Icons.remove_rounded, 'Minimizar asistente', _minimizar),
      ],
    );
    return Container(
      key: const Key('asistente_encabezado'),
      padding: EdgeInsets.fromLTRB(
        18,
        compacto ? 10 : 18,
        12,
        compacto ? 10 : 14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF122E62), Color(0xFF283574), Color(0xFF514197)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (!compacto) ...[
                const AsistenteSimbolo(size: 42),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asistente IA de Formación',
                      maxLines: compacto ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.25,
                        height: 1.3,
                      ),
                    ),
                    if (!compacto) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Tu copiloto de capacitación',
                        style: TextStyle(
                          color: Color(0xFFD5DFF8),
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!dosFilas) ...[const SizedBox(width: 4), acciones],
            ],
          ),
          if (dosFilas) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: acciones),
          ],
        ],
      ),
    );
  }

  Widget _accionHeader(IconData icono, String tooltip, VoidCallback? accion) =>
      IconButton(
        tooltip: tooltip,
        onPressed: accion,
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF8B99BF),
          hoverColor: const Color(0x22FFFFFF),
          focusColor: const Color(0x33FFFFFF),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icono, size: 20),
      );

  Widget _conversacion(EstadoChat estado, bool real) => ClipRect(
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
                color: const Color(0xFFF0F3FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 16,
                    color: Color(0xFF647399),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      real
                          ? 'Contexto dinámico · Datos de demostración del proyecto'
                          : 'Ayuda conceptual · Indicadores deshabilitados',
                      style: const TextStyle(
                        color: Color(0xFF536180),
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (estado.mensajes.isEmpty &&
                !estado.enviando &&
                estado.error == null)
              _bienvenida(estado.enviando)
            else ...[
              const SizedBox(height: 20),
              for (final mensaje in estado.mensajes)
                Padding(
                  key: GlobalObjectKey(mensaje),
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AsistenteMensaje(mensaje: mensaje),
                ),
            ],
            if (estado.enviando) const _AnalizandoConsulta(),
            if (estado.error != null) _error(estado.error!),
          ],
        ),
      ),
    ),
  );

  Widget _error(String error) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFF2D9B7)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF986020),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No pudimos completar la consulta',
                  style: TextStyle(
                    color: Color(0xFF754615),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  error,
                  style: const TextStyle(
                    color: Color(0xFF754F29),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Podés editar tu consulta y volver a enviarla.',
                  style: TextStyle(
                    color: Color(0xFF846343),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _editor(
    EstadoChat estado,
    DestinoAsistente destino,
    bool compacto,
  ) => ListenableBuilder(
    listenable: Listenable.merge([_texto, _focus]),
    builder: (context, _) {
      final valor = _texto.value;
      final puedeEnviar =
          !estado.enviando &&
          valor.text.trim().isNotEmpty &&
          (!valor.composing.isValid || valor.composing.isCollapsed);
      return Container(
        key: const Key('asistente_editor'),
        padding: EdgeInsets.fromLTRB(
          14,
          compacto ? 8 : 12,
          14,
          compacto ? 8 : 12,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE6EAF4))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: _movimiento(context, 140),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _focus.hasFocus ? _violeta : const Color(0xFFDDE3F0),
                  width: 1.5,
                ),
                boxShadow: [
                  if (_focus.hasFocus)
                    const BoxShadow(color: Color(0x126451D8), blurRadius: 10),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Focus(
                      canRequestFocus: false,
                      onKeyEvent: (_, event) => _teclaEditor(event, destino),
                      child: TextField(
                        key: const Key('asistente_input'),
                        controller: _texto,
                        focusNode: _focus,
                        maxLength: AsistenteContextoService.maxPregunta,
                        minLines: 1,
                        maxLines: compacto ? 2 : 4,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorColor: _violeta,
                        style: const TextStyle(
                          color: _tinta,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Preguntale algo sobre la formación...',
                          hintMaxLines: 2,
                          constraints: BoxConstraints(minHeight: 56),
                          hintStyle: TextStyle(
                            color: Color(0xFF758198),
                            fontSize: 14,
                          ),
                          counterText: '',
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
                      duration: _movimiento(context, 140),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: puedeEnviar
                            ? const LinearGradient(
                                colors: [Color(0xFF3462CE), Color(0xFF7954D6)],
                              )
                            : null,
                        color: puedeEnviar ? null : const Color(0xFFEBEEF6),
                      ),
                      child: IconButton(
                        tooltip: estado.enviando
                            ? 'Esperá la respuesta para enviar otra consulta'
                            : 'Enviar pregunta',
                        onPressed: puedeEnviar ? () => _enviar(destino) : null,
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF8E99B0),
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
            if (!compacto) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    estado.enviando
                        ? 'Podés preparar tu próxima pregunta'
                        : 'Enter para enviar · Shift + Enter para otra línea',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64728B),
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                  if (valor.text.length > 1000)
                    Text(
                      '${valor.text.length}/${AsistenteContextoService.maxPregunta}',
                      style: const TextStyle(
                        color: Color(0xFF64728B),
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Consultas independientes. No compartas credenciales.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64728B),
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _bienvenida(bool enviando) => Padding(
    padding: const EdgeInsets.only(top: 30, bottom: 12),
    child: Column(
      children: [
        const AsistenteSimbolo(size: 68, halo: true),
        const SizedBox(height: 22),
        const Text(
          '¡Hola! ¿En qué puedo ayudarte?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _tinta,
            fontSize: 23,
            height: 1.25,
            letterSpacing: -.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Analizá indicadores, explorá capacitaciones y encontrá respuestas sobre tu organización.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF62708B), fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas =
                constraints.maxWidth >= 360 &&
                MediaQuery.textScalerOf(context).scale(14) < 19;
            final ancho = columnas
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            const sugerencias = [
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
                for (final (icono, pregunta) in sugerencias)
                  SizedBox(
                    width: ancho,
                    child: OutlinedButton(
                      onPressed: enviando
                          ? null
                          : () {
                              _texto.value = TextEditingValue(
                                text: pregunta,
                                selection: TextSelection.collapsed(
                                  offset: pregunta.length,
                                ),
                              );
                              _focus.requestFocus();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF394B70),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE0E5F2)),
                        padding: const EdgeInsets.all(14),
                        minimumSize: Size(0, columnas ? 100 : 66),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icono, size: 21, color: _violeta),
                          const SizedBox(height: 9),
                          Text(
                            pregunta,
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

Duration _movimiento(BuildContext context, int milisegundos) =>
    MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)
    ? Duration.zero
    : Duration(milliseconds: milisegundos);

class _BotonCopiloto extends StatefulWidget {
  final VoidCallback onPressed;
  const _BotonCopiloto({required this.onPressed});

  @override
  State<_BotonCopiloto> createState() => _BotonCopilotoState();
}

class _BotonCopilotoState extends State<_BotonCopiloto> {
  bool _hover = false;
  bool _foco = false;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: _movimiento(context, 350),
    curve: Curves.easeOutCubic,
    builder: (context, valor, child) => Opacity(
      opacity: valor,
      child: Transform.scale(scale: .85 + .15 * valor, child: child),
    ),
    child: AnimatedScale(
      scale: _hover || _foco ? 1.05 : 1,
      duration: _movimiento(context, 160),
      child: AnimatedContainer(
        duration: _movimiento(context, 160),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _foco ? const Color(0xFF17243D) : Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(_hover || _foco ? 0x506F55D8 : 0x306F55D8),
              blurRadius: 26,
              spreadRadius: 2,
            ),
            const BoxShadow(
              color: Color(0x301F65BE),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Tooltip(
          message: 'Preguntale a la IA',
          child: SizedBox(
            width: _tamanoSimbolo,
            height: _tamanoSimbolo,
            child: Stack(
              children: [
                const AsistenteSimbolo(size: _tamanoSimbolo),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onPressed,
                      onHover: (valor) => setState(() => _hover = valor),
                      onFocusChange: (valor) => setState(() => _foco = valor),
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

class _AnalizandoConsulta extends StatefulWidget {
  const _AnalizandoConsulta();

  @override
  State<_AnalizandoConsulta> createState() => _AnalizandoConsultaState();
}

class _AnalizandoConsultaState extends State<_AnalizandoConsulta>
    with SingleTickerProviderStateMixin {
  late final _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_movimiento(context, 1) == Duration.zero) {
      _animacion.stop();
      _animacion.value = .5;
    } else {
      _animacion.repeat();
    }
  }

  @override
  void dispose() {
    _animacion.dispose();
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
            const AsistenteSimbolo(size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Analizando tu consulta...',
                style: TextStyle(
                  color: Color(0xFF4C5875),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _animacion,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final onda =
                      (math.sin(_animacion.value * math.pi * 2 - i * .9) + 1) /
                      2;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Opacity(
                      opacity: .3 + .7 * onda,
                      child: Transform.translate(
                        offset: Offset(0, -2 * onda),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF7364CF),
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
