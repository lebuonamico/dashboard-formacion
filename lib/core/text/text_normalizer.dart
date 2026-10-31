const _accented = 'áéíóúüñ';
const _plain = 'aeiouun';

/// Lowercase text without accents in which every run of characters other
/// than `a-z` and `0-9` becomes [separator].
String normalizeKey(String text, {String separator = ''}) {
  var value = text.trim().toLowerCase();
  for (var i = 0; i < _accented.length; i++) {
    value = value.replaceAll(_accented[i], _plain[i]);
  }
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), separator).trim();
}

/// Trimmed lowercase text, keeping accents and symbols.
String normalizeLoose(String text) => text.trim().toLowerCase();
