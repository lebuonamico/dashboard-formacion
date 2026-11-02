// Non-web fallback; no browser APIs or persistent credentials are needed.
String? _reason;

void writeRejectionReason(String reason) => _reason = reason;

String? readRejectionReason() => _reason;

String? takeRejectionReason() {
  final reason = _reason;
  _reason = null;
  return reason;
}

void clearRejectionReason() => _reason = null;
