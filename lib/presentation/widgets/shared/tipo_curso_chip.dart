import 'package:flutter/material.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

/// Etiqueta de color para la categoría de un curso. La usan el catálogo de
/// cursos y las certificaciones LMS, para que cada tipo tenga siempre el mismo
/// color.
class TipoCursoChip extends StatelessWidget {
  final TipoCurso tipo;

  const TipoCursoChip({super.key, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final (bg, text) = switch (tipo) {
      TipoCurso.habilidadesDeNegocio => (
        const Color(0xFFEFF6FF),
        const Color(0xFF1D4ED8),
      ),
      TipoCurso.habilidadesBlandas => (
        const Color(0xFFF3E8FF),
        const Color(0xFF7E22CE),
      ),
      TipoCurso.libresExploracion => (
        const Color(0xFFECFDF5),
        const Color(0xFF047857),
      ),
      TipoCurso.dictadoCapacitaciones => (
        const Color(0xFFFFF7ED),
        const Color(0xFFC2410C),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tipo.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
