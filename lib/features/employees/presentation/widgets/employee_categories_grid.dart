import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/card_rows.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';
import 'package:flutter/material.dart';

/// The four categories of the plan: in a row on desktop, 2 × 2 below 840 px
/// and one per row on the narrowest phones.
class EmployeeCategoriesGrid extends StatelessWidget {
  final EmployeeCompliance compliance;

  const EmployeeCategoriesGrid(this.compliance, {super.key});

  @override
  Widget build(BuildContext context) {
    if (context.windowSize != WindowSize.expanded) {
      return CardRows(
        columns: MediaQuery.sizeOf(context).width < 360 ? 1 : 2,
        spacing: 12,
        children: CourseCategory.values
            .map(
              (type) =>
                  _CategoryCard(type: type, compliance: compliance, fill: true),
            )
            .toList(),
      );
    }
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

  /// As tall as its row (in `CardRows`): the label takes two lines and the
  /// bar goes to the bottom, so the bars of a row line up.
  final bool fill;

  const _CategoryCard({
    required this.type,
    required this.compliance,
    this.fill = false,
  });

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
            maxLines: fill ? 2 : 1,
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
          if (fill) const Spacer(),
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
