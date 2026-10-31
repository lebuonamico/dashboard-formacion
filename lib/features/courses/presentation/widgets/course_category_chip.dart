import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_colors.dart';

/// Color label for a course category. The catalog and the LMS
/// certifications use it, so each type always has the same color (the one in
/// the dashboard charts).
class CourseCategoryChip extends StatelessWidget {
  final CourseCategory type;

  const CourseCategoryChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) =>
      ColorLabel(text: type.label, colors: context.colors.category(type));
}
