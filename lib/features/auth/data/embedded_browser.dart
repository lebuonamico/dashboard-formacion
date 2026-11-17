import 'embedded_browser_user_agent_stub.dart'
    if (dart.library.js_interop) 'embedded_browser_user_agent_web.dart'
    as user_agent;

/// Whether the page runs inside an app's own browser (WhatsApp, Instagram,
/// LinkedIn…), where Google refuses to sign in (`disallowed_useragent`).
bool runsInEmbeddedBrowser() {
  final agent = user_agent.read();
  return agent != null && isEmbeddedBrowser(agent);
}

const _appTokens = [
  'FBAN',
  'FBAV',
  'Instagram',
  'LinkedInApp',
  'Line/',
  'MicroMessenger',
  'Twitter',
];

/// Classifies a user agent: an Android WebView (`; wv)`), an iOS WebView
/// (no `Safari/` token, which Safari, Chrome and Firefox for iOS all carry) or
/// a known app's browser. Unknown agents count as a regular browser, so the
/// notice is never shown by mistake on one.
bool isEmbeddedBrowser(String userAgent) {
  if (_appTokens.any(userAgent.contains)) return true;
  if (userAgent.contains('Android')) return userAgent.contains('; wv)');
  final iOS = RegExp(r'iPhone|iPad|iPod').hasMatch(userAgent);
  return iOS && userAgent.contains('Mobile/') && !userAgent.contains('Safari/');
}
