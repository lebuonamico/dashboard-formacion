import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';

/// Etiqueta de color para la categoría de un curso. La usan el catálogo de
/// cursos y las certificaciones LMS, para que cada tipo tenga siempre el mismo
/// color (el mismo que en los gráficos del dashboard).
class CourseCategoryChip extends StatelessWidget {
  final CourseCategory type;

  const CourseCategoryChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) =>
      ColorLabel(text: type.label, colors: context.colors.category(type));
}
