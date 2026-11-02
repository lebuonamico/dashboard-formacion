import 'package:app_finnegans/features/courses/domain/course_category.dart';

extension CourseCategoryLabel on CourseCategory {
  String get label => switch (this) {
    CourseCategory.businessSkills => 'Habilidades de negocio',
    CourseCategory.softSkills => 'Habilidades blandas',
    CourseCategory.exploration => 'Libres / exploración',
    CourseCategory.teaching => 'Dictado de capacitaciones',
  };

  /// For charts, legends and table headers.
  String get shortLabel => switch (this) {
    CourseCategory.businessSkills => 'Negocio',
    CourseCategory.softSkills => 'Blandas',
    CourseCategory.exploration => 'Libres',
    CourseCategory.teaching => 'Dictado',
  };
}
