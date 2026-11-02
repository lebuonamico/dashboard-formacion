import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';

/// Reads the seniority written in a payroll spreadsheet or in the history
/// table: `SSr2`, `Jr 3`, `Senior II`, `semisenior segundo`, `S1`, `M`...
/// Text it does not recognise is rejected instead of becoming a default level.
class SeniorityParser {
  const SeniorityParser();

  static final _accepted = RegExp(
    r'^trainee(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)?$|^t$'
    r'|^(?:junior|jr|j|senior|senor|sr|s)(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)?$'
    r'|^(?:semisenior|semisenor|ssr|ss)(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)$'
    r'|^(?:manager|gerente|m)$',
  );

  static const _aliases = {
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

  Seniority parse(String text) =>
      tryParse(text) ??
      (throw FormatException('Seniority inválido: "${text.trim()}".'));

  Seniority? tryParse(String text) {
    final compact = normalizeKey(text);
    if (compact.isEmpty) return null;
    final exact =
        Seniority.values
            .asNameMap()
            .entries
            .where((entry) => entry.key.toLowerCase() == compact)
            .firstOrNull
            ?.value ??
        _aliases[compact];
    if (exact != null) return exact;
    if (!_accepted.hasMatch(compact)) return null;
    return _interpret(normalizeKey(text, separator: ' '), compact);
  }

  Seniority? _interpret(String words, String compact) {
    final normalized = words
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
    return null;
  }

  static Seniority _levelled(Seniority base, int level) {
    const values = Seniority.values;
    final index = values.indexOf(base) + level - 1;
    return values[index.clamp(0, values.length - 1)];
  }

  static const _levelWords = {
    'primero': 1,
    'segundo': 2,
    'tercero': 3,
    'uno': 1,
    'dos': 2,
    'tres': 3,
  };

  static int? _extractLevel(String normalized, String compact) {
    final numeric = RegExp(
      r'(?:^|[^0-9])([123])(?:[a-z]+)?(?:$|[^a-z0-9])',
    ).firstMatch(normalized);
    if (numeric != null) return int.tryParse(numeric.group(1)!);
    final word = _levelWords.entries
        .where((entry) => compact.endsWith(entry.key))
        .firstOrNull;
    if (word != null) return word.value;
    if (compact.endsWith('iii')) return 3;
    if (compact.endsWith('ii')) return 2;
    if (compact.endsWith('i')) return 1;
    return null;
  }
}
