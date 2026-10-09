import 'package:flutter/material.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';

/// Etiqueta de color para el seniority de un colaborador. Cada familia de
/// nivel (Trainee, Junior, Semisenior, Senior, Manager) tiene su color; se
/// evitan los colores del semáforo para que no se lea como un estado.
class SeniorityChip extends StatelessWidget {
  final Seniority seniority;

  const SeniorityChip({super.key, required this.seniority});

  @override
  Widget build(BuildContext context) {
    final (bg, text) = switch (seniority) {
      Seniority.trainee => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
      Seniority.junior1 ||
      Seniority.junior2 ||
      Seniority.junior3 => (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      Seniority.semisenior1 ||
      Seniority.semisenior2 ||
      Seniority.semisenior3 => (
        const Color(0xFFEDE9FE),
        const Color(0xFF6D28D9),
      ),
      Seniority.senior1 ||
      Seniority.senior2 ||
      Seniority.senior3 => (const Color(0xFFDBEAFE), const Color(0xFF0D53C3)),
      Seniority.manager => (const Color(0xFFCCFBF1), const Color(0xFF0F766E)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        seniority.label,
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
