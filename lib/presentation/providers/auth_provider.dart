import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';

String? googleOAuthRedirectTo({required bool isWeb, required Uri baseUri}) =>
    isWeb ? baseUri.origin : null;

class AuthController extends ChangeNotifier {
  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  String? error;
  bool isSigningIn = false;
  bool _disposed = false;

  AuthController(this._client) {
    _subscription = _client?.auth.onAuthStateChange.listen(
      (state) {
        error = null;
        notifyListeners();
      },
      onError: (Object authError, StackTrace stackTrace) {
        error =
            'No se pudo actualizar la sesión. Intentá iniciar sesión nuevamente.';
        notifyListeners();
      },
    );
  }

  bool get enabled => _client != null;

  bool get hasValidSession {
    final session = _client?.auth.currentSession;
    return session != null && !session.isExpired;
  }

  String? redirect(String path) {
    if (!enabled) return null;
    final isLogin = path == '/' || path == '/login';
    if (!hasValidSession) return path == '/login' ? null : '/login';
    return isLogin ? '/dashboard' : null;
  }

  Future<void> signInWithGoogle() async {
    if (!enabled || isSigningIn || _disposed) return;
    isSigningIn = true;
    error = null;
    notifyListeners();
    try {
      final launched = await _client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: googleOAuthRedirectTo(isWeb: kIsWeb, baseUri: Uri.base),
      );
      if (!launched) {
        error = 'No se pudo abrir el inicio de sesión con Google.';
      }
    } catch (_) {
      error = 'No se pudo iniciar sesión con Google. Intentá nuevamente.';
    } finally {
      isSigningIn = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final authControllerProvider = ChangeNotifierProvider<AuthController>(
  (ref) => AuthController(
    SupabaseConfig.enabled ? ref.watch(supabaseClientProvider) : null,
  ),
);
