import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/presentation/import_file_type_labels.dart';
import 'package:app_finnegans/features/imports/presentation/widgets/import_section.dart';
import 'package:app_finnegans/features/training_plan/presentation/training_plan_editor.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Configuración del sistema'),
          Expanded(
            child: ListView(
              padding: screenPadding,
              children: [
                for (final type in ImportFileType.values) ...[
                  _ConfigCard(
                    title: type.sectionTitle,
                    subtitle: type.sectionSubtitle,
                    children: [ImportSection(type: type)],
                  ),
                  const SizedBox(height: 24),
                ],
                const _ConfigCard(
                  title: 'Objetivo de formación por seniority',
                  subtitle:
                      'Horas mensuales requeridas por categoría. Cada cambio rige desde '
                      'el mes que elijas: los meses anteriores conservan su objetivo.',
                  children: [TrainingPlanEditor()],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _ConfigCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
