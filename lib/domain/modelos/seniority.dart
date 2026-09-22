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
    final clean = _normalize(raw);
    final compact = clean.replaceAll(' ', '');
    final exact = _matchConfiguredValue(compact);
    if (exact != null) return exact;

    final normalized = clean
        .replaceAll(RegExp(r'\bprimero\b'), '1')
        .replaceAll(RegExp(r'\bsegundo\b'), '2')
        .replaceAll(RegExp(r'\btercero\b'), '3')
        .replaceAll(RegExp(r'\buno\b'), '1')
        .replaceAll(RegExp(r'\bdos\b'), '2')
        .replaceAll(RegExp(r'\btres\b'), '3');

    if (compact.contains('trainee') || compact == 't') {
      return Seniority.trainee;
    }
    final hasJunior =
        compact.contains('junior') ||
        compact.contains('jr') ||
        compact.startsWith('j');
    final hasSemiSenior =
        compact.contains('semisenior') ||
        compact.contains('semisenor') ||
        compact.contains('ssr') ||
        compact.startsWith('ss');
    final hasSenior =
        !hasSemiSenior &&
        (compact.contains('senior') ||
            compact.contains('senor') ||
            compact.contains('sr') ||
            RegExp(r'^s(?:[123]|i{1,3})$').hasMatch(compact));
    final level = _extractLevel(normalized, compact);

    if (hasJunior && level != null) {
      return _levelled(Seniority.junior1, level);
    }
    if (hasSemiSenior && level != null) {
      return _levelled(Seniority.semisenior1, level);
    }
    if (hasSenior && level != null) {
      return _levelled(Seniority.senior1, level);
    }

    if (compact.contains('manager') ||
        compact.contains('gerente') ||
        compact == 'm') {
      return Seniority.manager;
    }
    if (compact.contains('senior') ||
        compact.contains('senor') ||
        compact == 'sr' ||
        compact == 's') {
      return Seniority.senior1;
    }
    if (compact.contains('junior') || compact == 'jr' || compact == 'j') {
      return Seniority.junior1;
    }

    return Seniority.junior1;
  }

  static String _normalize(String raw) {
    return raw
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
  }

  static Seniority? _matchConfiguredValue(String compact) {
    for (final seniority in Seniority.values) {
      if (_normalize(seniority.name).replaceAll(' ', '') == compact ||
          _normalize(seniority.label).replaceAll(' ', '') == compact) {
        return seniority;
      }
    }

    const aliases = {
      't': Seniority.trainee,
      'j1': Seniority.junior1,
      'jr1': Seniority.junior1,
      'j2': Seniority.junior2,
      'jr2': Seniority.junior2,
      'j3': Seniority.junior3,
      'jr3': Seniority.junior3,
      'ss1': Seniority.semisenior1,
      'ssr1': Seniority.semisenior1,
      'ss2': Seniority.semisenior2,
      'ssr2': Seniority.semisenior2,
      'ss3': Seniority.semisenior3,
      'ssr3': Seniority.semisenior3,
      's1': Seniority.senior1,
      'sr1': Seniority.senior1,
      's2': Seniority.senior2,
      'sr2': Seniority.senior2,
      's3': Seniority.senior3,
      'sr3': Seniority.senior3,
      'm': Seniority.manager,
    };
    return aliases[compact];
  }

  static Seniority _levelled(Seniority base, int level) {
    final values = Seniority.values;
    final index = values.indexOf(base) + level - 1;
    return values[index.clamp(0, values.length - 1)];
  }

  static int? _extractLevel(String normalized, String compact) {
    final numeric = RegExp(
      r'(?:^|[^0-9])([123])(?:[a-z]+)?(?:$|[^a-z0-9])',
    ).firstMatch(normalized);
    if (numeric != null) return int.tryParse(numeric.group(1)!);
    if (compact.endsWith('iii')) return 3;
    if (compact.endsWith('ii')) return 2;
    if (compact.endsWith('i')) return 1;
    return null;
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
