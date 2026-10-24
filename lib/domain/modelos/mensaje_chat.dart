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
  final bool puedeReintentar;

  const EstadoChat({
    this.abierto = false,
    this.enviando = false,
    this.mensajes = const [],
    this.error,
    this.puedeReintentar = false,
  });

  EstadoChat copyWith({
    bool? abierto,
    bool? enviando,
    List<MensajeChat>? mensajes,
    String? error,
    bool? puedeReintentar,
  }) => EstadoChat(
    abierto: abierto ?? this.abierto,
    enviando: enviando ?? this.enviando,
    mensajes: mensajes ?? this.mensajes,
    error: error,
    puedeReintentar: puedeReintentar ?? this.puedeReintentar,
  );
}
