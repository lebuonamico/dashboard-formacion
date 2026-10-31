import 'package:app_finnegans/features/auth/data/user_role_codes.dart';
import 'package:app_finnegans/features/auth/data/access_rejection.dart';
import 'package:app_finnegans/features/auth/domain/auth_repository.dart';
import 'package:app_finnegans/features/auth/domain/auth_user.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

String? googleOAuthRedirectTo({required bool isWeb, required Uri baseUri}) =>
    isWeb ? '${baseUri.origin}/' : null;

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Stream<AuthChange> changes() => _client.auth.onAuthStateChange.map(
    (state) => state.event == AuthChangeEvent.signedOut
        ? AuthChange.signedOut
        : AuthChange.updated,
  );

  @override
  AuthUser? currentUser() {
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    if (session == null || session.isExpired || user == null) return null;
    final metadata = user.userMetadata ?? const {};
    String? metadataValue(List<String> keys) => keys
        .map((key) => metadata[key])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    return AuthUser(
      id: user.id,
      email: user.email,
      name: metadataValue(const ['full_name', 'name']),
      photoUrl: metadataValue(const ['avatar_url', 'picture']),
    );
  }

  /// The user is allowed only while active and with neither a block nor a
  /// deletion stamp. A row without those columns counts as not stamped.
  @override
  Future<AuthorizationResult> checkAuthorization(String email) async {
    final row = await _client
        .schema('public')
        .from('usuarios_autorizados')
        .select('activo,rol,ff_eliminar,ff_bloqueo')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    final isAllowed =
        row != null &&
        row['activo'] == true &&
        row['ff_eliminar'] == null &&
        row['ff_bloqueo'] == null;
    final storedRole = row?['rol'] as String?;
    return AuthorizationResult(
      isAllowed: isAllowed,
      role: storedRole == null ? null : userRoleFromDb(storedRole),
    );
  }

  @override
  Future<bool> signInWithGoogle() => _client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: googleOAuthRedirectTo(isWeb: kIsWeb, baseUri: Uri.base),
  );

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  void rememberRejection() => rememberUnauthorizedAccess();

  @override
  String? rejectionMessage() => readAccessRejectionMessage();

  @override
  void clearRejection() => clearAccessRejection();
}
