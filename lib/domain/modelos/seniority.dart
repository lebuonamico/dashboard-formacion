import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

enum Seniority {
  trainee('Trainee', negocio: 4, blandas: 4, libres: 0, dictado: 0),
  junior1('Junior 1', negocio: 4, blandas: 4, libres: 0, dictado: 0),
  junior2('Junior 2', negocio: 4, blandas: 4, libres: 0, dictado: 0),
  junior3('Junior 3', negocio: 3, blandas: 4, libres: 1, dictado: 0),
  semisenior1('Semisenior 1', negocio: 3, blandas: 4, libres: 1, dictado: 0),
  semisenior2('Semisenior 2', negocio: 2, blandas: 4, libres: 1, dictado: 1),
  semisenior3('Semisenior 3', negocio: 1, blandas: 4, libres: 1, dictado: 2),
  senior1('Senior 1', negocio: 0, blandas: 2, libres: 2, dictado: 4),
  senior2('Senior 2', negocio: 0, blandas: 2, libres: 2, dictado: 4),
  senior3('Senior 3', negocio: 0, blandas: 2, libres: 2, dictado: 4),
  manager('Manager', negocio: 0, blandas: 0, libres: 8, dictado: 0);

  final String label;
  final double negocio;
  final double blandas;
  final double libres;
  final double dictado;

  const Seniority(
    this.label, {
    required this.negocio,
    required this.blandas,
    required this.libres,
    required this.dictado,
  });

  /// Mapea el texto del Excel a su enum correspondiente
  static Seniority fromString(String raw) {
    final clean = raw
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final compact = clean.replaceAll(' ', '');
    final normalized = clean
        .replaceAll(RegExp(r'\bprimero\b'), '1')
        .replaceAll(RegExp(r'\bsegundo\b'), '2')
        .replaceAll(RegExp(r'\btercero\b'), '3')
        .replaceAll(RegExp(r'\buno\b'), '1')
        .replaceAll(RegExp(r'\bdos\b'), '2')
        .replaceAll(RegExp(r'\btres\b'), '3');

    if (compact.contains('trainee')) {
      return Seniority.trainee;
    }
    final hasJunior = compact.contains('junior') || compact.contains('jr') || compact.startsWith('j');
    final hasSemiSenior = compact.contains('semisenior') ||
      compact.contains('semisenor') ||
      compact.contains('ssr');
    final hasSenior = !hasSemiSenior &&
      (compact.contains('senior') || compact.contains('sr') ||
        RegExp(r'^s(?:[123]|i{1,3})$').hasMatch(compact));
    final level = _extractLevel(normalized, compact);

    if (hasJunior && level != null) return _levelled(Seniority.junior1, level);
    if (hasSemiSenior && level != null) return _levelled(Seniority.semisenior1, level);
    if (hasSenior && level != null) return _levelled(Seniority.senior1, level);
    if (_matchesLevel(normalized, compact, const ['junior','Junior', 'jr', 'j'], 1)) {
      return Seniority.junior1;
    }
    if (_matchesLevel(normalized, compact, const ['junior','Junior', 'jr', 'j'], 2)) {
      return Seniority.junior2;
    }
    if (_matchesLevel(normalized, compact, const ['junior', 'jr', 'j'], 3)) {
      return Seniority.junior3;
    }
    if (_matchesLevel(normalized, compact, const ['semisenior', 'semisenor', 'semi senor', 'ssr', 'ss'], 1)) {
      return Seniority.semisenior1;
    }
    if (_matchesLevel(normalized, compact, const ['semisenior', 'semisenor', 'semi senor', 'ssr', 'ss'], 2)) {
      return Seniority.semisenior2;
    }
    if (_matchesLevel(normalized, compact, const ['semisenior', 'semisenor', 'semi senor', 'ssr', 'ss'], 3)) {
      return Seniority.semisenior3;
    }
    if (_matchesLevel(normalized, compact, const ['senior', 'Señor', 'sr', 's'], 1)) {
      return Seniority.senior1;
    }
    if (_matchesLevel(normalized, compact, const ['senior', 'Señor', 'sr', 's'], 2)) {
      return Seniority.senior2;
    }
    if (_matchesLevel(normalized, compact, const ['senior', 'sr', 's'], 3)) {
      return Seniority.senior3;
    }
    if (compact.contains('manager') || compact.contains('gerente')) {
      return Seniority.manager;
    }
    if (compact.contains('senior') || compact == 'sr' || compact == 's') {
      return Seniority.senior1;
    }

    if (compact.contains('junior') || compact == 'jr' || compact == 'j') {
      return Seniority.junior1;
    }

    return Seniority.junior1;
  }

  static Seniority _levelled(Seniority base, int level) {
    final values = Seniority.values;
    final index = values.indexOf(base) + level - 1;
    return values[index.clamp(0, values.length - 1)];
  }

  static int? _extractLevel(String normalized, String compact) {
    final numeric = RegExp(r'(?:^|[^0-9])([123])(?:$|[^0-9])').firstMatch(normalized);
    if (numeric != null) return int.tryParse(numeric.group(1)!);
    if (compact.endsWith('iii')) return 3;
    if (compact.endsWith('ii')) return 2;
    if (compact.endsWith('i')) return 1;
    return null;
  }

  static bool _matchesLevel(
    String normalized,
    String compact,
    List<String> prefixes,
    int level,
  ) {
    final levelText = level.toString();
    return prefixes.any((prefix) {
      final normalizedPrefix = prefix.replaceAll(' ', '');
      return normalized == '$prefix $levelText' ||
          compact == '$normalizedPrefix$levelText' ||
          compact == '$normalizedPrefix${_roman(level)}';
    });
  }

  static String _roman(int level) {
    switch (level) {
      case 1:
        return 'i';
      case 2:
        return 'ii';
      case 3:
        return 'iii';
      default:
        return '';
    }
  }

  double horasRequeridas(TipoCurso tipo) {
    switch (tipo) {
      case TipoCurso.habilidadesDeNegocio:
        return negocio;
      case TipoCurso.habilidadesBlandas:
        return blandas;
      case TipoCurso.libresExploracion:
        return libres;
      case TipoCurso.dictadoCapacitaciones:
        return dictado;
    }
  }

  Map<TipoCurso, double> get planFormacion => {
        TipoCurso.habilidadesDeNegocio: negocio,
        TipoCurso.habilidadesBlandas: blandas,
        TipoCurso.libresExploracion: libres,
        TipoCurso.dictadoCapacitaciones: dictado,
      };
}