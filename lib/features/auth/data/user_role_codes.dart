import 'package:app_finnegans/features/auth/domain/user_role.dart';

const _userRoleCodes = {
  UserRole.admin: 'admin',
  UserRole.academy: 'academia',
  UserRole.areaLead: 'area',
  UserRole.teamLead: 'lider',
};

String userRoleToDb(String role) {
  final known = UserRole.values.asNameMap()[role];
  return known == null ? role : _userRoleCodes[known]!;
}

String userRoleFromDb(String role) =>
    _userRoleCodes.entries
        .where((entry) => entry.value == role.trim().toLowerCase())
        .firstOrNull
        ?.key
        .name ??
    role;
