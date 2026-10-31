import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_donut_chart.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';

class TeamCategoryDistribution extends StatelessWidget {
  final double businessHours;
  final double softSkillsHours;
  final double explorationHours;
  final double teachingHours;
  final bool isAnnual;

  const TeamCategoryDistribution({
    super.key,
    required this.businessHours,
    required this.softSkillsHours,
    required this.explorationHours,
    required this.teachingHours,
    this.isAnnual = false,
  });

  @override
  Widget build(BuildContext context) {
    final total =
        businessHours + softSkillsHours + explorationHours + teachingHours;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.panel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                children: [
                  Text(
                    'Distribución por categoría',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: isAnnual
                        ? 'Suma de las horas válidas por categoría de los meses con datos del año.'
                        : 'Horas validadas del período que aplican al objetivo de cada integrante, agrupadas por categoría.',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 166),
              child: Center(
                child: TeamDonutChart(
                  centerValue: total.toStringAsFixed(1),
                  centerLabel: 'HORAS',
                  valueSuffix: ' h',
                  slices: [
                    TeamDonutSlice(
                      label: CourseCategory.businessSkills.shortLabel,
                      help:
                          'Horas de capacitaciones asociadas a habilidades de negocio y herramientas.',
                      value: businessHours,
                      color: context.colors.business.text,
                    ),
                    TeamDonutSlice(
                      label: CourseCategory.softSkills.shortLabel,
                      help:
                          'Horas de capacitaciones clasificadas como habilidades blandas.',
                      value: softSkillsHours,
                      color: context.colors.softSkills.text,
                    ),
                    TeamDonutSlice(
                      label: CourseCategory.exploration.shortLabel,
                      help:
                          'Horas de formación libre o exploratoria realizadas por los integrantes.',
                      value: explorationHours,
                      color: context.colors.exploration.text,
                    ),
                    TeamDonutSlice(
                      label: CourseCategory.teaching.shortLabel,
                      help:
                          'Horas cargadas como dictado de capacitaciones por integrantes del equipo.',
                      value: teachingHours,
                      color: context.colors.teaching.text,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
