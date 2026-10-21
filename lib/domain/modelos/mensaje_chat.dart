class MensajeChat {
  final String texto;
  final bool esUsuario;
  final String contexto;

  const MensajeChat({
    required this.texto,
    required this.esUsuario,
    required this.contexto,
  });
}

class EstadoChat {
  final bool abierto;
  final bool enviando;
  final List<MensajeChat> mensajes;
  final String? error;

  const EstadoChat({
    this.abierto = false,
    this.enviando = false,
    this.mensajes = const [],
    this.error,
  });

  EstadoChat copyWith({
    bool? abierto,
    bool? enviando,
    List<MensajeChat>? mensajes,
    String? error,
  }) => EstadoChat(
    abierto: abierto ?? this.abierto,
    enviando: enviando ?? this.enviando,
    mensajes: mensajes ?? this.mensajes,
    error: error,
  );
}
