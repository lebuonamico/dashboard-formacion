import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/domain/user_role_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = UserRoleParser();

  group('UserRoleParser.tryParse', () {
    test('Reconoce name y label, con acentos, espacios y mayúsculas', () {
      expect(parser.tryParse('admin'), UserRole.admin);
      expect(parser.tryParse('  ADMIN '), UserRole.admin);
      expect(parser.tryParse('Administrador'), UserRole.admin);
      expect(parser.tryParse('academy'), UserRole.academy);
      expect(parser.tryParse('Academia'), UserRole.academy);
      expect(parser.tryParse('Área'), UserRole.areaLead);
      expect(parser.tryParse('areaLead'), UserRole.areaLead);
      expect(parser.tryParse('teamLead'), UserRole.teamLead);
      expect(parser.tryParse('Líder de equipo'), UserRole.teamLead);
    });

    test('Solo Administrador y Academia son gestores', () {
      expect(UserRole.admin.canManage, isTrue);
      expect(UserRole.academy.canManage, isTrue);
      expect(UserRole.areaLead.canManage, isFalse);
      expect(UserRole.teamLead.canManage, isFalse);
    });

    test('Devuelve null ante lo irreconocible, sin caer en un rol', () {
      for (final raw in ['', '   ', 'usuario', 'superadmin', 'xyz']) {
        expect(parser.tryParse(raw), isNull, reason: raw);
      }
      expect(parser.tryParse(null), isNull);
    });
  });
}
