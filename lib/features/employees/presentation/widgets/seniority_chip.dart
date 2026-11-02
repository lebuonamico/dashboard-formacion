import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/employees/presentation/seniority_colors.dart';

/// Color label for an employee's seniority. Each level family (Trainee,
/// Junior, Semisenior, Senior, Manager) has its color; traffic-light colors are
/// avoided so it does not read as a status.
class SeniorityChip extends StatelessWidget {
  final Seniority seniority;

  const SeniorityChip({super.key, required this.seniority});

  @override
  Widget build(BuildContext context) => ColorLabel(
    text: seniority.label,
    colors: context.colors.level(seniority),
  );
}
