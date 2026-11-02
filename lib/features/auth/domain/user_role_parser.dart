import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';

/// Recognises a role by its name or its display text, ignoring accents,
/// spaces and case.
class UserRoleParser {
  static const _aliases = {
    UserRole.admin: 'Administrador',
    UserRole.academy: 'Academia',
    UserRole.areaLead: 'Área',
    UserRole.teamLead: 'Líder de equipo',
  };

  const UserRoleParser();

  /// `null` if the text is empty or not a known role.
  UserRole? tryParse(String? raw) {
    if (raw == null) return null;
    final clean = normalizeKey(raw);
    if (clean.isEmpty) return null;
    return UserRole.values
        .where(
          (role) =>
              normalizeKey(role.name) == clean ||
              normalizeKey(_aliases[role]!) == clean,
        )
        .firstOrNull;
  }
}
