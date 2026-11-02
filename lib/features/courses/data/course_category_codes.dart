import 'package:app_finnegans/features/courses/domain/course_category.dart';

const _courseCategoryCodes = {
  CourseCategory.businessSkills: 'habilidadesDeNegocio',
  CourseCategory.softSkills: 'habilidadesBlandas',
  CourseCategory.exploration: 'libresExploracion',
  CourseCategory.teaching: 'dictadoCapacitaciones',
};

String courseCategoryToDb(CourseCategory category) =>
    _courseCategoryCodes[category]!;

String? courseCategoryFromDb(Object? code) => _courseCategoryCodes.entries
    .where((entry) => entry.value == code)
    .firstOrNull
    ?.key
    .name;
