const _accented = 'áéíóúüñ';
const _plain = 'aeiouun';

/// Lowercase text without accents in which every run of characters other
/// than `a-z` and `0-9` becomes [separator], never at either end.
String normalizeKey(String text, {String separator = ''}) {
  final value = List.generate(_accented.length, (i) => i).fold(
    text.trim().toLowerCase(),
    (value, i) => value.replaceAll(_accented[i], _plain[i]),
  );
  return value
      .replaceAll(RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), separator);
}

/// Trimmed lowercase text, keeping accents and symbols.
String normalizeLoose(String text) => text.trim().toLowerCase();
