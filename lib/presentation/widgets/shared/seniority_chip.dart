import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/presentation/widgets/shared/etiqueta_color.dart';
import 'package:flutter/material.dart';

/// Etiqueta de color para el seniority de un colaborador. Cada familia de
/// nivel (Trainee, Junior, Semisenior, Senior, Manager) tiene su color; se
/// evitan los colores del semáforo para que no se lea como un estado.
class SeniorityChip extends StatelessWidget {
  final Seniority seniority;

  const SeniorityChip({super.key, required this.seniority});

  @override
  Widget build(BuildContext context) => ColorLabel(
    text: seniority.label,
    colors: context.colors.level(seniority),
  );
}
