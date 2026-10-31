/// Emails, links, keys, tokens and credentials: they never reach the AI.
class SensitiveTextDetector {
  static final _pattern = RegExp(
    r'@|https?://|\beyJ[A-Za-z0-9_-]+\.|\bAIza[A-Za-z0-9_-]+|\b(?:sk-|sb_secret_|sb_publishable_)[A-Za-z0-9_-]+|\bBearer\s+\S+|(?:api[_ -]?key|password|contrase[nñ]a|clave|token|secret)\s*[:=]\s*\S+|\b[A-Za-z0-9_-]{36,}\b',
    caseSensitive: false,
  );

  const SensitiveTextDetector();

  bool isSensitive(String text) => _pattern.hasMatch(text);
}
