import 'package:app_finnegans/domain/modelos/registro_importacion.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

const _courseCategoryCodes = {
  CourseCategory.businessSkills: 'habilidadesDeNegocio',
  CourseCategory.softSkills: 'habilidadesBlandas',
  CourseCategory.exploration: 'libresExploracion',
  CourseCategory.teaching: 'dictadoCapacitaciones',
};

const _userRoleCodes = {
  UserRole.admin: 'admin',
  UserRole.academy: 'academia',
  UserRole.areaLead: 'area',
  UserRole.teamLead: 'lider',
};

const _importStatusCodes = {
  ImportStatus.completed: 'completada',
  ImportStatus.failed: 'fallida',
};

String courseCategoryToDb(CourseCategory category) =>
    _courseCategoryCodes[category]!;

String? courseCategoryFromDb(Object? code) => _courseCategoryCodes.entries
    .where((entry) => entry.value == code)
    .firstOrNull
    ?.key
    .name;

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

String importStatusToDb(ImportStatus status) => _importStatusCodes[status]!;
