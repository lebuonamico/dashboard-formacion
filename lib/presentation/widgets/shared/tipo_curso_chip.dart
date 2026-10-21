import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/widgets/shared/etiqueta_color.dart';
import 'package:flutter/material.dart';

/// Etiqueta de color para la categoría de un curso. La usan el catálogo de
/// cursos y las certificaciones LMS, para que cada tipo tenga siempre el mismo
/// color (el mismo que en los gráficos del dashboard).
class TipoCursoChip extends StatelessWidget {
  final TipoCurso tipo;

  const TipoCursoChip({super.key, required this.tipo});

  @override
  Widget build(BuildContext context) => EtiquetaColor(
    texto: tipo.label,
    colores: context.colores.categoria(tipo),
  );
}
