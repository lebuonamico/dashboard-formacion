import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';

String? googleOAuthRedirectTo({required bool isWeb, required Uri baseUri}) =>
    isWeb ? baseUri.origin : null;

class AuthController extends ChangeNotifier {
  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  String? error;
  bool isSigningIn = false;
  bool isValidatingAuthorization = false;
  String? rol;
  (String, String?)? _authorizedUser;
  (String, String?)? _validatingUser;
  Future<void>? _authorizationFuture;
  int _authorizationRevision = 0;
  bool _disposed = false;

  AuthController(this._client) {
    _subscription = _client?.auth.onAuthStateChange.listen(
      (state) {
        if (_disposed) return;
        if (state.event == AuthChangeEvent.signedOut) _clearAuthorization();
        _updateSession();
      },
      onError: (Object authError, StackTrace stackTrace) {
        if (_disposed) return;
        _clearAuthorization();
        error =
            'No se pudo actualizar la sesión. Intentá iniciar sesión nuevamente.';
        notifyListeners();
      },
    );
    // Restored sessions must be gated before the router's first redirect.
    if (hasValidSession) unawaited(validateAuthorization());
  }

  bool get enabled => _client != null;

  bool get hasValidSession {
    final session = _client?.auth.currentSession;
    return session != null && !session.isExpired;
  }

  (String, String?)? get _currentUser {
    final user = _client?.auth.currentUser;
    return hasValidSession && user != null ? (user.id, user.email) : null;
  }

  bool get isAuthorized =>
      hasValidSession &&
      _authorizedUser != null &&
      _authorizedUser == _currentUser;

  /// Mail del usuario autorizado, para mostrarlo en la interfaz.
  String? get email => isAuthorized ? _authorizedUser?.$2 : null;

  bool get esAdmin => isAuthorized && rol == RolUsuario.admin.name;

  void _clearAuthorization() {
    _authorizationRevision++;
    _authorizedUser = null;
    _validatingUser = null;
    _authorizationFuture = null;
    isValidatingAuthorization = false;
    rol = null;
  }

  void _updateSession() {
    if (_disposed) return;
    if (!hasValidSession) {
      _clearAuthorization();
      // Keep a denial visible after the automatic signedOut event.
      notifyListeners();
    } else if (!isAuthorized) {
      unawaited(validateAuthorization());
    } else {
      notifyListeners();
    }
  }

  Future<void> validateAuthorization() {
    if (_disposed || !enabled) return Future.value();
    final user = _currentUser;
    if (user == null) {
      _clearAuthorization();
      notifyListeners();
      return Future.value();
    }
    if (_validatingUser == user && _authorizationFuture != null) {
      return _authorizationFuture!;
    }
    final revision = ++_authorizationRevision;
    _authorizedUser = null;
    rol = null;
    error = null;
    _validatingUser = user;
    isValidatingAuthorization = true;
    final validation = _validateAuthorization(user, revision);
    _authorizationFuture = validation;
    notifyListeners();
    return validation;
  }

  bool _isCurrentValidation((String, String?) user, int revision) =>
      !_disposed && revision == _authorizationRevision && _currentUser == user;

  Future<void> _validateAuthorization(
    (String, String?) user,
    int revision,
  ) async {
    try {
      final email = user.$2;
      final row = email == null || email.isEmpty
          ? null
          : await _client!
                .schema('public')
                .from('usuarios_autorizados')
                .select('activo,rol,ff_eliminar,ff_bloqueo')
                .eq('email', email.trim().toLowerCase())
                .maybeSingle();
      if (!_isCurrentValidation(user, revision)) return;
      if (row != null &&
          row['activo'] == true &&
          row['ff_eliminar'] == null &&
          row['ff_bloqueo'] == null) {
        rol = row['rol'] as String?;
        _authorizedUser = user;
      } else {
        error = 'Tu usuario no está autorizado para acceder a esta aplicación.';
        try {
          await _client!.auth.signOut();
        } catch (_) {
          // Supabase clears the local session before attempting remote logout.
        }
      }
    } catch (_) {
      if (!_isCurrentValidation(user, revision)) return;
      error =
          'No se pudo validar la autorización de tu usuario. Intentá nuevamente.';
    } finally {
      if (!_disposed && revision == _authorizationRevision) {
        _validatingUser = null;
        _authorizationFuture = null;
        isValidatingAuthorization = false;
        notifyListeners();
      }
    }
  }

  String? redirect(String path) {
    if (!enabled) return null;
    final isLogin = path == '/' || path == '/login';
    if (!isAuthorized) return path == '/login' ? null : '/login';
    if (path.startsWith('/admin') && !esAdmin) return '/dashboard';
    return isLogin ? '/dashboard' : null;
  }

  Future<void> signInWithGoogle() async {
    if (!enabled || isSigningIn || isValidatingAuthorization || _disposed) {
      return;
    }
    if (hasValidSession) {
      await validateAuthorization();
      return;
    }
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
    _clearAuthorization();
    error = null;
    if (!_disposed) notifyListeners();
    await _client?.auth.signOut();
  }

  @override
  void dispose() {
    _disposed = true;
    _clearAuthorization();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final authControllerProvider = ChangeNotifierProvider<AuthController>(
  (ref) => AuthController(
    SupabaseConfig.enabled ? ref.watch(supabaseClientProvider) : null,
  ),
);
