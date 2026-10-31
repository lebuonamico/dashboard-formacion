import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';

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
