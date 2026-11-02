enum AuthChange { signedOut, updated }

class AuthUser {
  final String id;
  final String? email;
  final String? name;
  final String? photoUrl;

  const AuthUser({required this.id, this.email, this.name, this.photoUrl});
}

class AuthorizationResult {
  final bool isAllowed;
  final String? role;

  const AuthorizationResult({required this.isAllowed, this.role});
}
