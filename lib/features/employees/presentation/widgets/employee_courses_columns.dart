import 'package:app_finnegans/core/formatting/date_formatter.dart';
import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry_record.dart';
import 'package:flutter/material.dart';

/// LMS and CRM side by side; stacked on narrow screens.
class EmployeeCoursesColumns extends StatelessWidget {
  final EmployeeDetail detail;

  const EmployeeCoursesColumns(this.detail, {super.key});

  @override
  Widget build(BuildContext context) {
    final columnMoodle = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(
          icon: Icons.school_outlined,
          title: 'LMS',
          detail: '${formatHours(detail.creditedLmsHours)} hs',
        ),
        const SizedBox(height: 8),
        _LmsCertificationsColumn(detail),
      ],
    );
    final columnCrm = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(
          icon: Icons.schedule_outlined,
          title: 'CRM (horas declaradas)',
          detail: '${formatHours(detail.crmHours)} hs',
        ),
        const SizedBox(height: 8),
        _TimeEntriesColumn(detail.timeEntryGroups),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [columnMoodle, const SizedBox(height: 24), columnCrm],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: columnMoodle),
            const SizedBox(width: 16),
            Expanded(child: columnCrm),
          ],
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _ColumnHeader({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        Text(
          detail,
          style: context.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String message;

  const _EmptyPanel(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.panel(),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _LmsCertificationsColumn extends StatelessWidget {
  final EmployeeDetail detail;

  const _LmsCertificationsColumn(this.detail);

  @override
  Widget build(BuildContext context) {
    if (detail.certifications.isEmpty) {
      return const _EmptyPanel('Sin certificaciones en el período.');
    }
    return Column(
      children: detail.certifications.map((item) {
        final certification = item.certification;
        final course = item.course;
        return _LmsCertificationCard(
          certification: certification,
          courseName: course?.name ?? certification.courseName,
          courseInfo: course == null
              ? 'Curso no encontrado en el catálogo'
              : '${course.category.label} · ${formatHours(course.workloadHours)} hs',
          dateText: formatDate(certification.completedAt!),
        );
      }).toList(),
    );
  }
}

class _TimeEntriesColumn extends StatelessWidget {
  final List<CourseTimeEntries> groups;

  const _TimeEntriesColumn(this.groups);

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _EmptyPanel('Sin cargas CRM en el período.');
    }
    return Column(children: groups.map(_CourseTimeEntriesTile.new).toList());
  }
}

class _CourseTimeEntriesTile extends StatelessWidget {
  final CourseTimeEntries group;

  const _CourseTimeEntriesTile(this.group);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final records = group.records;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: context.panel(radius: 6),
      // A Material of its own: the ink of the tile would paint behind the
      // panel's color.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey<String>('curso-${group.key}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.menu_book_outlined,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  group.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (group.isCompleted) ...[
                const SizedBox(width: 8),
                ColorLabel(text: 'Finalizado', colors: context.colors.success),
              ],
            ],
          ),
          subtitle: Text(
            '${records.first.course?.category.label ?? 'Tipo sin especificar'} · '
            '${records.length} ${records.length == 1 ? 'registro' : 'registros'} · '
            '${formatHours(group.hours)} hs declaradas',
            style: context.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          children: [
            const Divider(height: 1),
            ...records.map(_TimeEntryRow.new),
          ],
        ),
      ),
    );
  }
}

class _TimeEntryRow extends StatelessWidget {
  final CrmTimeEntryRecord record;

  const _TimeEntryRow(this.record);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatDate(record.timeEntry.date),
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.intermediateText,
              ),
            ),
          ),
          if (record.isTaught) ...[
            ColorLabel(text: 'Dictada', colors: colors.teaching),
            const SizedBox(width: 8),
          ],
          Text(
            '${formatHours(record.timeEntry.hours)} hs',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _LmsCertificationCard extends StatelessWidget {
  final LmsCertification certification;
  final String courseName;
  final String courseInfo;
  final String dateText;

  const _LmsCertificationCard({
    required this.certification,
    required this.courseName,
    required this.courseInfo,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final completed = certification.isCompleted;
    final cs = context.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: context.panel(radius: 6),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ColorLabel(
                      text: completed ? 'Finalizado' : 'Pendiente',
                      colors: completed
                          ? context.colors.success
                          : context.colors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$courseInfo · ${completed ? 'Finalizó' : 'Fecha'} $dateText',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
