import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/widgets/shared/etiqueta_color.dart';
import 'package:flutter/material.dart';

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
