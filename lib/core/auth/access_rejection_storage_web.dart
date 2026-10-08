import 'dart:js_interop';

const _storageKey = 'auth_rejection_reason';

@JS('window.sessionStorage')
external _SessionStorage get _sessionStorage;

extension type _SessionStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

// Keep logout working even when the browser denies access to web storage.
String? _fallbackReason;

void writeRejectionReason(String reason) {
  _fallbackReason = reason;
  try {
    _sessionStorage.setItem(_storageKey, reason);
  } catch (_) {}
}

String? readRejectionReason() {
  var reason = _fallbackReason;
  try {
    reason = _sessionStorage.getItem(_storageKey) ?? reason;
  } catch (_) {}
  return reason;
}

String? takeRejectionReason() {
  final reason = readRejectionReason();
  clearRejectionReason();
  return reason;
}

void clearRejectionReason() {
  _fallbackReason = null;
  try {
    _sessionStorage.removeItem(_storageKey);
  } catch (_) {}
}
