import 'package:app_finnegans/core/theme/app_colors.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

extension CourseCategoryColors on AppColors {
  ColorPair category(CourseCategory type) => switch (type) {
    CourseCategory.businessSkills => business,
    CourseCategory.softSkills => softSkills,
    CourseCategory.exploration => exploration,
    CourseCategory.teaching => teaching,
  };
}
