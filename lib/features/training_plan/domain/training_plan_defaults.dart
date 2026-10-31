import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';

/// Monthly hours per category that applied while the plan was fixed in code.
/// They rule every month before the first saved plan version.
abstract final class TrainingPlanDefaults {
  static const plan = TrainingPlan(hours);

  static const hours = <Seniority, Map<CourseCategory, double>>{
    Seniority.trainee: {
      CourseCategory.businessSkills: 4,
      CourseCategory.softSkills: 4,
      CourseCategory.exploration: 0,
      CourseCategory.teaching: 0,
    },
    Seniority.junior1: {
      CourseCategory.businessSkills: 4,
      CourseCategory.softSkills: 4,
      CourseCategory.exploration: 0,
      CourseCategory.teaching: 0,
    },
    Seniority.junior2: {
      CourseCategory.businessSkills: 4,
      CourseCategory.softSkills: 4,
      CourseCategory.exploration: 0,
      CourseCategory.teaching: 0,
    },
    Seniority.junior3: {
      CourseCategory.businessSkills: 3,
      CourseCategory.softSkills: 4,
      CourseCategory.exploration: 1,
      CourseCategory.teaching: 0,
    },
    Seniority.semisenior1: {
      CourseCategory.businessSkills: 3,
      CourseCategory.softSkills: 4,
      CourseCategory.exploration: 1,
      CourseCategory.teaching: 0,
    },
    Seniority.semisenior2: {
      CourseCategory.businessSkills: 2,
      CourseCategory.softSkills: 4,
      CourseCategory.exploration: 1,
      CourseCategory.teaching: 1,
    },
    Seniority.semisenior3: {
      CourseCategory.businessSkills: 1,
      CourseCategory.softSkills: 4,
      CourseCategory.exploration: 1,
      CourseCategory.teaching: 2,
    },
    Seniority.senior1: {
      CourseCategory.businessSkills: 0,
      CourseCategory.softSkills: 2,
      CourseCategory.exploration: 2,
      CourseCategory.teaching: 4,
    },
    Seniority.senior2: {
      CourseCategory.businessSkills: 0,
      CourseCategory.softSkills: 2,
      CourseCategory.exploration: 2,
      CourseCategory.teaching: 4,
    },
    Seniority.senior3: {
      CourseCategory.businessSkills: 0,
      CourseCategory.softSkills: 2,
      CourseCategory.exploration: 2,
      CourseCategory.teaching: 4,
    },
    Seniority.manager: {
      CourseCategory.businessSkills: 0,
      CourseCategory.softSkills: 0,
      CourseCategory.exploration: 8,
      CourseCategory.teaching: 0,
    },
  };
}
