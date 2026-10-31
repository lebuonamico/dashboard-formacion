import 'package:app_finnegans/features/auth/domain/user_role.dart';

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Administrador',
    UserRole.academy => 'Academia',
    UserRole.areaLead => 'Área',
    UserRole.teamLead => 'Líder de equipo',
  };

  String get description => switch (this) {
    UserRole.admin ||
    UserRole.academy => 'Ve toda la empresa y administra usuarios y líderes',
    UserRole.areaLead => 'Ve los equipos de las áreas que lidera',
    UserRole.teamLead => 'Ve los integrantes de los equipos que lidera',
  };
}
