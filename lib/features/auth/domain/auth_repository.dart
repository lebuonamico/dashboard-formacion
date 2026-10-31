import 'package:app_finnegans/features/auth/domain/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthChange> changes();

  /// The user of a valid (non expired) session, or `null`.
  AuthUser? currentUser();

  Future<AuthorizationResult> checkAuthorization(String email);

  /// `false` when the browser could not open the Google sign in.
  Future<bool> signInWithGoogle();

  Future<void> signOut();

  /// The reason survives the OAuth redirect and the page reload, so the login
  /// screen can explain why the session was closed.
  void rememberRejection();

  String? rejectionMessage();

  void clearRejection();
}
