enum TipoCurso {
  habilidadesDeNegocio('Habilidades de negocio'),
  habilidadesBlandas('Habilidades blandas'),
  libresExploracion('Libres / exploración'),
  dictadoCapacitaciones('Dictado de capacitaciones');

  final String label;
  const TipoCurso(this.label);

  /// Reconoce la categoría a partir de un texto como la Clasificación del CRM,
  /// sin distinguir mayúsculas, tildes ni símbolos.
  static TipoCurso? desdeTexto(String? texto) {
    if (texto == null) return null;
    final buscado = _normalizar(texto);
    if (buscado.isEmpty) return null;
    for (final tipo in TipoCurso.values) {
      if (_normalizar(tipo.label) == buscado) return tipo;
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
