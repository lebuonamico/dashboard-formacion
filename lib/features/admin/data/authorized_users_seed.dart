import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';

final _createdAt = DateTime(2026, 1, 5);

AuthorizedUser _user(String email, UserRole role) => AuthorizedUser(
  email: email,
  role: role.name,
  isActive: true,
  createdAt: _createdAt,
);

final authorizedUsersSeed = [
  _user('admin@finnegans-demo.com', UserRole.admin),
  _user('academia@finnegans-demo.com', UserRole.academy),
  _user('lucas.gomez@finnegans-demo.com', UserRole.teamLead),
  _user('valeria.rios@finnegans-demo.com', UserRole.areaLead),
  _user('sebastian.gonzalez@finnegans-demo.com', UserRole.teamLead),
  _user(
    'diego.fernandez@finnegans-demo.com',
    UserRole.teamLead,
  ).blocked(DateTime(2026, 9)),
];
