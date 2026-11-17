import 'package:app_finnegans/features/auth/data/embedded_browser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the login runs in an app's own browser, where Google refuses to
/// sign in.
final embeddedBrowserProvider = Provider<bool>(
  (ref) => runsInEmbeddedBrowser(),
);
