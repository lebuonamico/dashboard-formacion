enum TipoCurso {
  habilidadesDeNegocio('Habilidades de negocio', 'Negocio'),
  habilidadesBlandas('Habilidades blandas', 'Blandas'),
  libresExploracion('Libres / exploración', 'Libres'),
  dictadoCapacitaciones('Dictado de capacitaciones', 'Dictado');

  final String label;

  /// Para gráficos, leyendas y encabezados de tabla.
  final String labelCorto;

  const TipoCurso(this.label, this.labelCorto);

  /// Reconoce la categoría a partir de la Clasificación del CRM o del catálogo
  /// (p. ej. "Habilidades de Negocio y Herramientas", "Horas de Dictado",
  /// "Exploracion / Profundizacion"), sin distinguir mayúsculas, tildes ni
  /// símbolos.
  static TipoCurso? desdeTexto(String? texto) {
    if (texto == null) return null;
    final buscado = _normalizar(texto);
    if (buscado.isEmpty) return null;
    for (final tipo in TipoCurso.values) {
      if (_normalizar(tipo.label) == buscado) return tipo;
    }
    if (buscado.contains('negocio') || buscado.contains('business')) {
      return TipoCurso.habilidadesDeNegocio;
    }
    if (buscado.contains('blanda') || buscado.contains('soft')) {
      return TipoCurso.habilidadesBlandas;
    }
    if (buscado.contains('dictad') || buscado.contains('impart')) {
      return TipoCurso.dictadoCapacitaciones;
    }
    if (buscado.contains('libre') ||
        buscado.contains('exploracion') ||
        buscado.contains('profundizacion')) {
      return TipoCurso.libresExploracion;
    }
    return null;
  }

  static String _normalizar(String texto) => texto
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
