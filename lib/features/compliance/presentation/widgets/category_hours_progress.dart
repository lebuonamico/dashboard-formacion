import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:flutter/material.dart';

class CategoryHoursProgress extends StatelessWidget {
  final EmployeeCompliance? compliance;
  final bool showOnlyApplicableHours;

  const CategoryHoursProgress({
    super.key,
    required this.compliance,
    this.showOnlyApplicableHours = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compliance == null) {
      return SizedBox(
        width: 256,
        child: Text(
          'Sin datos de cumplimiento',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      width: 256,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final type in CourseCategory.values) _buildCard(context, type),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, CourseCategory type) {
    final colors = context.colors;
    final registeredHours = compliance!.creditedHours[type] ?? 0.0;
    final completedHours = showOnlyApplicableHours
        ? compliance!.applicableHours(type)
        : registeredHours;
    final requiredHours = compliance!.requiredHours[type] ?? 0.0;
    final required = requiredHours > 0;
    final meets = required && completedHours >= requiredHours;
    final ColorPair(text: color, :background) = !required
        ? colors.neutral
        : meets
        ? colors.success
        : colors.warning;

    return Tooltip(
      message: required
          ? '${type.label}: ${_formatHours(completedHours)} de ${_formatHours(requiredHours)} horas'
          : registeredHours > 0
          ? '${type.label}: no requerida; ${_formatHours(registeredHours)} h registradas no suman al cumplimiento'
          : '${type.label}: no requerida; no suma al cumplimiento',
      child: Container(
        width: 125,
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                type.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: colors.intermediateText),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_formatHours(completedHours)}/${_formatHours(requiredHours)} h',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHours(double hours) => hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
}
