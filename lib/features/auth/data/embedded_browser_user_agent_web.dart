import 'dart:js_interop';

@JS('window.navigator.userAgent')
external String? get _userAgent;

String? read() {
  try {
    return _userAgent;
  } catch (_) {
    return null;
  }
}
