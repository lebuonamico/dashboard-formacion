enum CourseCategory {
  businessSkills('Habilidades de negocio', 'Negocio'),
  softSkills('Habilidades blandas', 'Blandas'),
  exploration('Libres / exploración', 'Libres'),
  teaching('Dictado de capacitaciones', 'Dictado');

  final String label;

  /// Para gráficos, leyendas y encabezados de tabla.
  final String shortLabel;

  const CourseCategory(this.label, this.shortLabel);

  /// Reconoce la categoría a partir de la Clasificación del CRM o del catálogo
  /// (p. ej. "Habilidades de Negocio y Herramientas", "Horas de Dictado",
  /// "Exploracion / Profundizacion"), sin distinguir mayúsculas, tildes ni
  /// símbolos.
  static CourseCategory? fromText(String? text) {
    if (text == null) return null;
    // Se consulta una vez por carga de horas y hay muy pocos textos
    // distintos: se resuelve cada uno una sola vez.
    if (_recognized.containsKey(text)) return _recognized[text];
    return _recognized[text] = _recognize(text);
  }

  static final _recognized = <String, CourseCategory?>{};

  static CourseCategory? _recognize(String text) {
    final searched = _normalize(text);
    if (searched.isEmpty) return null;
    for (final type in CourseCategory.values) {
      if (_normalize(type.label) == searched) return type;
    }
    if (searched.contains('negocio') || searched.contains('business')) {
      return CourseCategory.businessSkills;
    }
    if (searched.contains('blanda') || searched.contains('soft')) {
      return CourseCategory.softSkills;
    }
    if (searched.contains('dictad') || searched.contains('impart')) {
      return CourseCategory.teaching;
    }
    if (searched.contains('libre') ||
        searched.contains('exploracion') ||
        searched.contains('profundizacion')) {
      return CourseCategory.exploration;
    }
    return null;
  }

  static String _normalize(String text) => text
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
