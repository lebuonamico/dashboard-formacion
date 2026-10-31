import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';

/// Reconoce un rol por su nombre o por el texto con el que se muestra, sin
/// importar tildes, espacios ni mayúsculas.
class UserRoleParser {
  static const _aliases = {
    UserRole.admin: 'Administrador',
    UserRole.academy: 'Academia',
    UserRole.areaLead: 'Área',
    UserRole.teamLead: 'Líder de equipo',
  };

  const UserRoleParser();

  /// `null` si el texto está vacío o no es un rol conocido.
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
