import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/projection/presentation/widgets/employee_projection_card.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;

  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(employeeDetailProvider(employeeId));
    final scope = ref.watch(periodFilterProvider).scope;
    final month = ref.watch(periodFilterProvider).month;
    final year = ref.watch(periodFilterProvider).year;
    final periodText = scope == PeriodScope.annual
        ? 'Año $year'
        : '${monthName(month)} $year';
    final hasPeriodData = ref.watch(hasTeamPeriodDataProvider).value ?? true;

    final sectionStyle = context.textTheme.bodyLarge!.copyWith(
      fontWeight: FontWeight.w700,
      color: context.colorScheme.onSurface,
    );

    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: 'Perfil del colaborador',
            onBack: () => context.pop(),
          ),

          // Contenido
          Expanded(
            child: detailAsync.when(
              // Al cambiar el período mantiene los datos previos en pantalla.
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorDataState(
                title: 'No pudimos cargar el colaborador',
                error: err,
              ),
              data: (detail) => FadeIn(
                child: (() {
                  if (detail == null) {
                    return const Center(child: Text('Empleado no encontrado.'));
                  }

                  final emp = detail.employee;
                  final currentCompliance = detail.compliance;

                  return ListView(
                    padding: screenPadding,
                    children: [
                      // Cabecera con datos del empleado
                      _buildEmployeeHeader(
                        context,
                        emp,
                        currentCompliance,
                        showCompliance: hasPeriodData,
                      ),
                      const SizedBox(height: 16),

                      // Filtro de período global
                      const PeriodFilterPanel(),
                      const SizedBox(height: 24),

                      if (!hasPeriodData) ...[
                        EmptyDataState.periodWithoutData(
                          period: periodLabel(scope, month, year),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Desglose de cumplimiento por categoría
                        Text(
                          'Desglose del plan de formación ($periodText)',
                          style: sectionStyle,
                        ),
                        const SizedBox(height: 12),
                        _buildCategoriesGrid(context, currentCompliance),
                        const SizedBox(height: 24),

                        if (ref
                                .watch(employeeProjectionProvider(employeeId))
                                .value
                            case final projection?) ...[
                          Text('Proyección a fin de año', style: sectionStyle),
                          const SizedBox(height: 12),
                          EmployeeProjectionCard(
                            projection: projection,
                            year: year,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Cursos del período: Moodle y CRM
                        Text(
                          'Cursos del período ($periodText)',
                          style: sectionStyle,
                        ),
                        const SizedBox(height: 12),
                        _buildCoursesColumns(context, detail),
                        const SizedBox(height: 24),
                      ],

                      // Cursos Dictados (si aplica al seniority)
                      if ((currentCompliance.requiredHours[CourseCategory
                                      .teaching] ??
                                  0) >
                              0 ||
                          detail.taughtCourses.isNotEmpty) ...[
                        Text(
                          'Cursos dictados como instructor',
                          style: sectionStyle,
                        ),
                        const SizedBox(height: 12),
                        _buildTaughtTable(context, detail.taughtCourses),
                      ],
                    ],
                  );
                })(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeader(
    BuildContext context,
    Employee emp,
    EmployeeCompliance currentCompliance, {
    required bool showCompliance,
  }) {
    final cs = context.colorScheme;
    final complianceStatus = currentCompliance.meetsTarget
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
              emp.firstName.trim().isEmpty
                  ? '?'
                  : emp.firstName.trim().substring(0, 1).toUpperCase(),
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
                    Text(
                      '${emp.firstName} ${emp.lastName}',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SeniorityChip(seniority: emp.seniority),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Área de ${emp.area} · Legajo: ${emp.employeeId}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emp.email,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _EmployeeData(label: 'Equipo', value: _showData(emp.team)),
                    _EmployeeData(
                      label: 'Gerente',
                      value: _showData(emp.manager),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Estado de Cumplimiento Global
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
                    '${currentCompliance.totalCreditedHours.toStringAsFixed(0)} / ${currentCompliance.totalRequiredHours.toStringAsFixed(0)} hs LMS',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: complianceStatus.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentCompliance.meetsTarget
                        ? 'Objetivo cumplido'
                        : 'En progreso',
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: complianceStatus.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CRM declaró ${currentCompliance.totalDeclaredHours.toStringAsFixed(0)} hs',
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

  String _showData(String value) => value.trim().isEmpty ? '-' : value;

  Widget _buildCategoriesGrid(
    BuildContext context,
    EmployeeCompliance currentCompliance,
  ) {
    return Row(
      children: CourseCategory.values.map((type) {
        final completed = currentCompliance.creditedHours[type] ?? 0.0;
        final declared = currentCompliance.declaredHours[type] ?? 0.0;
        final required = currentCompliance.requiredHours[type] ?? 0.0;
        final isRequired = required > 0;
        final meets = isRequired && completed >= required;
        // Libres y Dictado no existen en el LMS: se cumplen con horas CRM.
        final source =
            type == CourseCategory.exploration ||
                type == CourseCategory.teaching
            ? 'CRM'
            : 'LMS';

        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
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
                      ? '${completed.toStringAsFixed(0)} / ${required.toStringAsFixed(0)} hs $source'
                      : 'No requerida',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: !isRequired
                        ? context.colorScheme.onSurfaceVariant
                        : meets
                        ? context.colors.success.text
                        : context.colors.danger.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CRM declaró ${declared.toStringAsFixed(0)} hs',
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
          ),
        );
      }).toList(),
    );
  }

  /// Muestra Moodle y CRM lado a lado; en pantallas angostas los apila.
  Widget _buildCoursesColumns(
    BuildContext context,
    EmployeeDetailViewModel detail,
  ) {
    final crmHours = detail.timeEntriesCrm.fold<double>(
      0,
      (total, item) => total + item.timeEntry.hours,
    );
    // Horas del catálogo de los cursos Moodle finalizados en el período.
    final moodleHours = detail.lmsCertifications
        .where((item) => item.isCompleted)
        .fold<double>(
          0,
          (total, item) =>
              total +
              (detail.courseByName(item.courseName)?.workloadHours ?? 0),
        );
    final columnMoodle = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildColumnHeader(
          context,
          icon: Icons.school_outlined,
          title: 'Moodle (LMS)',
          detail: '${_formatHours(moodleHours)} hs',
        ),
        const SizedBox(height: 8),
        _buildColumnMoodle(context, detail),
      ],
    );
    final columnCrm = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildColumnHeader(
          context,
          icon: Icons.schedule_outlined,
          title: 'CRM (horas declaradas)',
          detail: '${_formatHours(crmHours)} hs',
        ),
        const SizedBox(height: 8),
        _buildTimeEntriesTable(
          context,
          detail.timeEntriesCrm,
          detail.completedCourses,
        ),
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

  Widget _buildColumnHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
  }) {
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

  Widget _buildEmptyState(BuildContext context, String message) {
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

  Widget _buildColumnMoodle(
    BuildContext context,
    EmployeeDetailViewModel detail,
  ) {
    if (detail.lmsCertifications.isEmpty) {
      return _buildEmptyState(context, 'Sin certificaciones en el período.');
    }

    return Column(
      children: detail.lmsCertifications.map((certification) {
        final course = detail.courseByName(certification.courseName);
        return _LmsCertificationCard(
          certification: certification,
          courseName: course?.name ?? certification.courseName,
          courseInfo: course == null
              ? 'Curso no encontrado en el catálogo'
              : '${course.category.label} · ${_formatHours(course.workloadHours)} hs',
          dateText: _formatDate(certification.completedAt!),
        );
      }).toList(),
    );
  }

  Widget _buildTimeEntriesTable(
    BuildContext context,
    List<CrmTimeEntryViewModel> timeEntries,
    Set<String> completedCourses,
  ) {
    if (timeEntries.isEmpty) {
      return _buildEmptyState(context, 'Sin cargas CRM en el período.');
    }
    final cs = context.colorScheme;
    final colors = context.colors;

    final groups = <String, List<CrmTimeEntryViewModel>>{};
    for (final timeEntry in timeEntries) {
      final courseId = timeEntry.course?.id.trim() ?? '';
      final courseName =
          timeEntry.course?.name ?? timeEntry.timeEntry.courseName;
      final key = courseId.isNotEmpty
          ? 'id:$courseId'
          : 'nombre:${courseName.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(timeEntry);
    }

    final groupedCourses = groups.entries.toList()
      ..sort((a, b) => _courseName(a.value).compareTo(_courseName(b.value)));

    return Column(
      children: groupedCourses.map((group) {
        final records = group.value
          ..sort((a, b) => b.timeEntry.date.compareTo(a.timeEntry.date));
        final firstTimeEntry = records.first;
        final courseName = _courseName(records);
        final completedCourse = completedCourses.contains(
          ComplianceService.normalizeCourseName(courseName),
        );
        final declaredHours = records.fold<double>(
          0,
          (total, item) => total + item.timeEntry.hours,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: context.panel(radius: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
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
                      courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (completedCourse) ...[
                    const SizedBox(width: 8),
                    ColorLabel(text: 'Finalizado', colors: colors.success),
                  ],
                ],
              ),
              subtitle: Text(
                '${firstTimeEntry.course?.category.label ?? 'Tipo sin especificar'} · '
                '${records.length} ${records.length == 1 ? 'registro' : 'registros'} · '
                '${_formatHours(declaredHours)} hs declaradas',
                style: context.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              children: [
                const Divider(height: 1),
                ...records.map((record) {
                  final dateText = _formatDate(record.timeEntry.date);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dateText,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.intermediateText,
                            ),
                          ),
                        ),
                        if (record.timeEntry.isTaught) ...[
                          ColorLabel(text: 'Dictada', colors: colors.teaching),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${_formatHours(record.timeEntry.hours)} hs',
                          style: context.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _courseName(List<CrmTimeEntryViewModel> timeEntries) {
    final first = timeEntries.first;
    return first.course?.name ?? first.timeEntry.courseName;
  }

  String _formatHours(double hours) => hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  Widget _buildTaughtTable(
    BuildContext context,
    List<TaughtCourseViewModel> taught,
  ) {
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
      decoration: context.panel(),
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          context.colorScheme.surfaceContainerLow,
        ),
        columns: const [
          DataColumn(
            label: Text(
              'Código',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Curso impartido',
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
        rows: taught.map((c) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  c.code,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(
                Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(Text(c.area)),
              DataCell(
                Text(
                  '${_formatHours(c.hours)} hs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.colors.teaching.text,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
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
                      text: completed ? 'Finalizado' : 'En curso',
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
