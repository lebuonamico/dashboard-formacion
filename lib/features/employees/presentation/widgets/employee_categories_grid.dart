import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';
import 'package:flutter/material.dart';

class EmployeeCategoriesGrid extends StatelessWidget {
  final EmployeeCompliance compliance;

  const EmployeeCategoriesGrid(this.compliance, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: CourseCategory.values
          .map(
            (type) => Expanded(
              child: _CategoryCard(type: type, compliance: compliance),
            ),
          )
          .toList(),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CourseCategory type;
  final EmployeeCompliance compliance;

  const _CategoryCard({required this.type, required this.compliance});

  @override
  Widget build(BuildContext context) {
    final completed = compliance.creditedHours[type] ?? 0.0;
    final declared = compliance.declaredHours[type] ?? 0.0;
    final required = compliance.requiredHours[type] ?? 0.0;
    final isRequired = required > 0;
    final meets = isRequired && completed >= required;
    // Exploration and Teaching do not exist in the LMS: CRM hours count.
    final source =
        type == CourseCategory.exploration || type == CourseCategory.teaching
        ? 'CRM'
        : 'LMS';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type.label,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            isRequired
                ? '${formatAchievedHours(completed, target: required)} / ${formatHours(required)} hs $source'
                : 'No requerida',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: !isRequired
                  ? context.colorScheme.onSurfaceVariant
                  : meets
                  ? context.colors.success.text
                  : context.colors.warning.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'CRM declaró ${formatHours(declared)} hs',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: required == 0
                  ? 0.0
                  : (completed / required).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: context.colorScheme.surfaceContainer,
              color: !isRequired
                  ? context.colorScheme.outlineVariant
                  : meets
                  ? context.colors.success.text
                  : context.colors.warning.text,
            ),
          ),
        ],
      ),
    );
  }
}
