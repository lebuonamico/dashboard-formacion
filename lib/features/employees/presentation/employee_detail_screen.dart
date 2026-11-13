import 'package:app_finnegans/core/formatting/date_formatter.dart';
import 'package:app_finnegans/core/navigation/app_destination.dart';
import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/projection/presentation/widgets/employee_projection_card.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;

  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(employeeDetailProvider(employeeId));

    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: 'Perfil del colaborador',
            backTo: originBackPath(
              GoRouterState.of(context).uri.queryParameters['origen'],
              '/empleados',
            ),
          ),
          Expanded(
            child: detailAsync.when(
              // Keeps the previous data on screen while the period changes.
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorDataState(
                title: 'No pudimos cargar el colaborador',
                error: err,
                onRetry: () =>
                    ref.invalidate(employeeDetailProvider(employeeId)),
              ),
              data: (detail) => FadeIn(
                child: detail == null
                    ? SingleChildScrollView(
                        child: EmptyDataState(
                          icon: Icons.person_off_outlined,
                          title: 'No encontramos al colaborador $employeeId.',
                          message:
                              'Puede no estar en la nómina o fuera de tu alcance.',
                        ),
                      )
                    : _EmployeeDetailBody(
                        employeeId: employeeId,
                        detail: detail,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeDetailBody extends ConsumerWidget {
  final String employeeId;
  final EmployeeDetail detail;

  const _EmployeeDetailBody({required this.employeeId, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);
    final periodText = period.scope == PeriodScope.annual
        ? 'Año ${period.year}'
        : '${monthName(period.month)} ${period.year}';
    final hasEmployeeData = detail.hasEmployeeData;
    final compliance = detail.compliance;
    final label = periodLabel(period.scope, period.month, period.year);
    final sectionStyle = context.textTheme.bodyLarge!.copyWith(
      fontWeight: FontWeight.w700,
      color: context.colorScheme.onSurface,
    );

    return ListView(
      padding: screenPadding,
      children: [
        _EmployeeHeader(
          employee: detail.employee,
          compliance: compliance,
          showCompliance: hasEmployeeData,
        ),
        const SizedBox(height: 16),
        const PeriodFilterPanel(
          included:
              'El colaborador cuenta desde su mes de ingreso, aunque tenga 0 '
              'horas.',
        ),
        const SizedBox(height: 24),
        if (!detail.hasPeriodData)
          EmptyDataState.periodWithoutData(period: label)
        else if (!hasEmployeeData)
          _EmployeeWithoutData(employee: detail.employee, period: label)
        else ...[
          Text(
            'Desglose del plan de formación ($periodText)',
            style: sectionStyle,
          ),
          const SizedBox(height: 12),
          _CategoriesGrid(compliance),
        ],
        const SizedBox(height: 24),
        _ProjectionSection(
          employeeId: employeeId,
          year: period.year,
          titleStyle: sectionStyle,
        ),
        if (hasEmployeeData) ...[
          Text('Cursos del período ($periodText)', style: sectionStyle),
          const SizedBox(height: 12),
          _CoursesColumns(detail),
          const SizedBox(height: 24),
        ],
        if (hasEmployeeData &&
            ((compliance.requiredHours[CourseCategory.teaching] ?? 0) > 0 ||
                detail.taughtCourses.isNotEmpty)) ...[
          Text('Cursos dictados como instructor', style: sectionStyle),
          const SizedBox(height: 12),
          _TaughtTable(detail.taughtCourses),
        ],
      ],
    );
  }
}

/// A period before the employee joined: no data, instead of everything at 0.
class _EmployeeWithoutData extends StatelessWidget {
  final Employee employee;
  final String period;

  const _EmployeeWithoutData({required this.employee, required this.period});

  @override
  Widget build(BuildContext context) {
    final hireDate = employee.hireDate;
    return EmptyDataState(
      icon: Icons.event_busy_outlined,
      title: 'No hay datos cargados del colaborador para $period.',
      message: hireDate == null
          ? null
          : 'Ingresó el ${formatDate(hireDate)}: sus datos se cuentan desde '
                'ese mes.',
    );
  }
}

/// Always shown, so an employee without data says so instead of losing the
/// section. Optional like the other projections: hidden while it loads or if
/// it fails.
class _ProjectionSection extends ConsumerWidget {
  final String employeeId;
  final int year;
  final TextStyle titleStyle;

  const _ProjectionSection({
    required this.employeeId,
    required this.year,
    required this.titleStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectionAsync = ref.watch(employeeProjectionProvider(employeeId));
    if (!projectionAsync.hasValue) return const SizedBox.shrink();
    final cutoffMonth = ref.watch(annualProjectionCutoffMonthProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Proyección a fin de año', style: titleStyle),
        const SizedBox(height: 12),
        if (projectionAsync.value case final projection?)
          EmployeeProjectionCard(projection: projection, year: year)
        else
          EmptyDataState(
            key: const Key('proyeccion_sin_datos'),
            compact: true,
            icon: Icons.trending_flat,
            title: 'Sin datos para proyectar.',
            message:
                'No hay datos cargados del colaborador'
                '${cutoffMonth == null ? ' en $year' : ' hasta ${monthName(cutoffMonth)} $year'}. '
                'La proyección usa sus meses con datos desde el ingreso.',
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _EmployeeHeader extends StatelessWidget {
  final Employee employee;
  final EmployeeCompliance compliance;
  final bool showCompliance;

  const _EmployeeHeader({
    required this.employee,
    required this.compliance,
    required this.showCompliance,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final complianceStatus = compliance.meetsTarget
        ? context.colors.success
        : context.colors.warning;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.panel(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: cs.primary,
            child: Text(
              employee.firstName.trim().isEmpty
                  ? '?'
                  : employee.firstName.trim().substring(0, 1).toUpperCase(),
              style: context.textTheme.displaySmall?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${employee.firstName} ${employee.lastName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SeniorityChip(seniority: employee.seniority),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Área: ${orDash(employee.area)} · Legajo ${employee.employeeId}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  orDash(employee.email),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _EmployeeData(
                      label: 'Equipo',
                      value: orDash(employee.team),
                    ),
                    _EmployeeData(
                      label: 'Líder',
                      value: orDash(employee.manager),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showCompliance)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: complianceStatus.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${formatAchievedHours(compliance.totalCreditedHours, target: compliance.totalRequiredHours)} / ${formatHours(compliance.totalRequiredHours)} hs válidas',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: complianceStatus.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    compliance.meetsTarget
                        ? 'Objetivo cumplido'
                        : 'En progreso',
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: complianceStatus.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CRM declaró ${formatHours(compliance.totalDeclaredHours)} hs',
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

class _CategoriesGrid extends StatelessWidget {
  final EmployeeCompliance compliance;

  const _CategoriesGrid(this.compliance);

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

/// LMS and CRM side by side; stacked on narrow screens.
class _CoursesColumns extends StatelessWidget {
  final EmployeeDetail detail;

  const _CoursesColumns(this.detail);

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

class _TaughtTable extends StatelessWidget {
  final List<TaughtCourse> taught;

  const _TaughtTable(this.taught);

  @override
  Widget build(BuildContext context) {
    if (taught.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: context.panel(),
        child: const Center(
          child: Text('No registra cursos dictados como instructor.'),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: context.panel(),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                context.colorScheme.surfaceContainerLow,
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    'ID',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Curso dictado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Área temática',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Horas sumadas al plan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: taught
                  .map(
                    (course) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            course.code,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            course.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(Text(course.area)),
                        DataCell(
                          Text(
                            '${formatHours(course.hours)} hs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: context.colors.teaching.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeData extends StatelessWidget {
  final String label;
  final String value;

  const _EmployeeData({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: context
          .panel(radius: 6)
          .copyWith(color: context.colorScheme.surfaceContainerLow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
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
