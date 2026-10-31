import 'dart:async';

import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/auth/data/access_rejection.dart';
import 'package:app_finnegans/features/auth/data/supabase_auth_repository.dart';
import 'package:app_finnegans/features/auth/domain/auth_repository.dart';
import 'package:app_finnegans/features/auth/domain/auth_user.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/features/auth/domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository?>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseAuthRepository(ref.watch(supabaseClientProvider))
      : null,
);

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

const _keep = Object();

class AuthState {
  final bool enabled;
  final AuthUser? user;
  final bool isAuthorized;
  final String? role;
  final bool isSigningIn;
  final bool isValidatingAuthorization;
  final String? error;

  const AuthState({
    this.enabled = true,
    this.user,
    this.isAuthorized = false,
    this.role,
    this.isSigningIn = false,
    this.isValidatingAuthorization = false,
    this.error,
  });

  const AuthState.disabled() : this(enabled: false);

  AuthState copyWith({
    Object? user = _keep,
    bool? isAuthorized,
    Object? role = _keep,
    bool? isSigningIn,
    bool? isValidatingAuthorization,
    Object? error = _keep,
  }) => AuthState(
    enabled: enabled,
    user: identical(user, _keep) ? this.user : user as AuthUser?,
    isAuthorized: isAuthorized ?? this.isAuthorized,
    role: identical(role, _keep) ? this.role : role as String?,
    isSigningIn: isSigningIn ?? this.isSigningIn,
    isValidatingAuthorization:
        isValidatingAuthorization ?? this.isValidatingAuthorization,
    error: identical(error, _keep) ? this.error : error as String?,
  );

  bool get hasValidSession => user != null;

  String? get email => isAuthorized ? user?.email : null;

  String? get name => isAuthorized ? user?.name : null;

  String? get photoUrl => isAuthorized ? user?.photoUrl : null;

  UserRole? get knownRole => isAuthorized ? UserRole.fromString(role) : null;

  bool get canManage => knownRole?.canManage ?? false;

  bool get isAdmin => isAuthorized && role == UserRole.admin.name;
}

/// Validates every new session against the allowlist. A late answer never
/// authorizes anyone: each validation carries a revision that a sign out or a
/// newer validation invalidates.
class AuthNotifier extends Notifier<AuthState> {
  final AuthState? _fixedState;

  AuthNotifier([this._fixedState]);

  int _revision = 0;
  AuthUser? _authorizedUser;
  AuthUser? _validatingUser;
  Future<void>? _validation;
  bool _denied = false;

  AuthRepository? get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    final fixedState = _fixedState;
    if (fixedState != null) return fixedState;
    // Filter selections belong to the user who made them.
    listenSelf((previous, next) {
      if (previous?.email != next.email) {
        ref.invalidate(dataFilterSelectionProvider);
      }
    });
    final repository = ref.watch(authRepositoryProvider);
    if (repository == null) return const AuthState.disabled();

    final subscription = repository.changes().listen(
      _onChange,
      onError: (Object _, StackTrace _) => _onChangeError(),
    );
    ref.onDispose(() {
      _clearAuthorization();
      unawaited(subscription.cancel());
    });

    final user = repository.currentUser();
    if (user == null) {
      final rejection = repository.rejectionMessage();
      repository.clearRejection();
      return AuthState(error: rejection);
    }
    // A restored session stays gated until the allowlist answers, so the
    // router never lets it through before that.
    final revision = ++_revision;
    _validatingUser = user;
    _validation = Future.microtask(() => _validate(user, revision));
    return AuthState(user: user, isValidatingAuthorization: true);
  }

  Future<void> validateAuthorization() {
    final repository = _repository;
    if (repository == null) return Future.value();
    final user = repository.currentUser();
    if (user == null) {
      _clearAuthorization();
      _publishSignedOut();
      return Future.value();
    }
    final validation = _validation;
    if (validation != null && _sameUser(_validatingUser, user)) {
      return validation;
    }
    final revision = ++_revision;
    _authorizedUser = null;
    _validatingUser = user;
    state = state.copyWith(
      user: user,
      isAuthorized: false,
      role: null,
      error: null,
      isValidatingAuthorization: true,
    );
    return _validation = _validate(user, revision);
  }

  Future<void> signInWithGoogle() async {
    final repository = _repository;
    if (repository == null ||
        state.isSigningIn ||
        state.isValidatingAuthorization) {
      return;
    }
    _denied = false;
    if (repository.currentUser() != null) {
      await validateAuthorization();
      return;
    }
    repository.clearRejection();
    state = state.copyWith(isSigningIn: true, error: null);
    try {
      final launched = await repository.signInWithGoogle();
      if (ref.mounted && !launched) {
        state = state.copyWith(
          error: 'No se pudo abrir el inicio de sesión con Google.',
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          error: 'No se pudo iniciar sesión con Google. Intentá nuevamente.',
        );
      }
    } finally {
      if (ref.mounted) state = state.copyWith(isSigningIn: false);
    }
  }

  Future<void> signOut() async {
    _clearAuthorization();
    _denied = false;
    state = state.copyWith(
      isAuthorized: false,
      role: null,
      error: null,
      isValidatingAuthorization: false,
    );
    await _repository?.signOut();
  }

  void _onChange(AuthChange change) {
    if (!ref.mounted) return;
    if (change == AuthChange.signedOut) _clearAuthorization();
    final user = _repository?.currentUser();
    if (user == null) {
      _clearAuthorization();
      _publishSignedOut();
    } else if (!_sameUser(_authorizedUser, user) && !_denied) {
      unawaited(validateAuthorization());
    } else {
      state = state.copyWith(
        user: user,
        isAuthorized: _sameUser(_authorizedUser, user),
      );
    }
  }

  void _onChangeError() {
    if (!ref.mounted) return;
    _clearAuthorization();
    state = state.copyWith(
      isAuthorized: false,
      role: null,
      isValidatingAuthorization: false,
      error:
          'No se pudo actualizar la sesión. Intentá iniciar sesión nuevamente.',
    );
  }

  Future<void> _validate(AuthUser user, int revision) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final email = user.email;
      final result = email == null || email.isEmpty
          ? const AuthorizationResult(isAllowed: false)
          : await repository.checkAuthorization(email);
      if (!_isCurrentValidation(user, revision)) return;
      if (result.isAllowed) {
        _authorizedUser = user;
        _denied = false;
        repository.clearRejection();
        state = state.copyWith(isAuthorized: true, role: result.role);
      } else {
        _denied = true;
        repository.rememberRejection();
        state = state.copyWith(error: unauthorizedAccessMessage);
        try {
          await repository.signOut();
        } catch (_) {
          // Supabase clears the local session before the remote logout.
        }
      }
    } catch (_) {
      if (!_isCurrentValidation(user, revision)) return;
      state = state.copyWith(
        error:
            'No se pudo validar la autorización de tu usuario. Intentá nuevamente.',
      );
    } finally {
      if (ref.mounted && revision == _revision) {
        _validatingUser = null;
        _validation = null;
        state = state.copyWith(isValidatingAuthorization: false);
      }
    }
  }

  bool _isCurrentValidation(AuthUser user, int revision) =>
      ref.mounted &&
      revision == _revision &&
      _sameUser(_repository?.currentUser(), user);

  void _clearAuthorization() {
    _revision++;
    _authorizedUser = null;
    _validatingUser = null;
    _validation = null;
  }

  void _publishSignedOut() => state = state.copyWith(
    user: null,
    isAuthorized: false,
    role: null,
    isValidatingAuthorization: false,
  );

  static bool _sameUser(AuthUser? a, AuthUser? b) =>
      a != null && b != null && a.id == b.id && a.email == b.email;
}

/// Route guard. Runs after the authorization check, so a missing role while
/// validating never lets anyone through.
String? authRedirect(AuthState auth, String path) {
  if (!auth.enabled) return null;
  final isLogin = path == '/' || path == '/login';
  if (!auth.isAuthorized) return path == '/login' ? null : '/login';
  if (isLogin) return '/dashboard';
  if (!auth.canManage &&
      (path.startsWith('/admin') || path.startsWith('/configuracion'))) {
    return '/dashboard';
  }
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  final isAreasOrAreaDetail =
      segments.isNotEmpty && segments.first == 'areas' && segments.length <= 2;
  if (auth.knownRole == UserRole.teamLead && isAreasOrAreaDetail) {
    return '/equipos';
  }
  return null;
}
