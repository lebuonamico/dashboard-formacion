import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/period/presentation/optional_period_filter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/paginated_table.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/courses/domain/course_stats.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/courses/presentation/widgets/course_category_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(courseStatsProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Catálogo de cursos y formaciones'),
          Expanded(
            child: Padding(
              padding: screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CoursesFilterBar(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: coursesAsync.when(
                      skipLoadingOnReload: true,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => ErrorDataState(
                        title: 'No pudimos cargar los cursos',
                        error: err,
                        onRetry: () => ref.invalidate(courseStatsProvider),
                      ),
                      data: (courses) => FadeIn(
                        child: courses.isEmpty
                            ? const _NoCourses()
                            : PaginatedTable(
                                items: courses,
                                rowHeight: _CoursesTable.rowHeight,
                                headerHeight: _CoursesTable.headerHeight,
                                resultsLabel: 'cursos',
                                icon: Icons.school_outlined,
                                tableBuilder: _CoursesTable.new,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells "nothing imported" apart from "nothing matches the filters".
class _NoCourses extends ConsumerWidget {
  const _NoCourses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCourses = ref.watch(coursesProvider).value?.isNotEmpty ?? false;
    return SingleChildScrollView(
      child: hasCourses
          ? const EmptyDataState(
              icon: Icons.search_off_outlined,
              title: 'No se encontraron cursos con los filtros aplicados.',
              message: 'Probá con otros filtros.',
            )
          : const EmptyDataState(
              icon: Icons.menu_book_outlined,
              title: 'No hay cursos cargados.',
              message: 'Importá el catálogo de cursos.',
            ),
    );
  }
}

class _CoursesFilterBar extends ConsumerWidget {
  const _CoursesFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(courseStatsPeriodProvider);
    return FilterBar(
      scope: DataFilterScope.courses,
      rows: ref.watch(courseFilterRowsProvider),
      extraFilters: [
        OptionalYearFilter(
          provider: courseStatsPeriodProvider,
          availableYears:
              ref.watch(availableCourseYearsProvider).value ?? const [],
          hint: 'Año (métricas)',
        ),
        OptionalMonthFilter(
          provider: courseStatsPeriodProvider,
          hint: 'Mes (métricas)',
        ),
      ],
      hasActiveExtraFilters: period.year != null || period.month != null,
      onClearExtraFilters: ref.read(courseStatsPeriodProvider.notifier).clear,
    );
  }
}

class _CoursesTable extends StatelessWidget {
  static const rowHeight = 44.0;
  static const headerHeight = 44.0;

  final List<CourseStats> courses;

  const _CoursesTable(this.courses);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return DataTable(
      columnSpacing: 24,
      headingRowHeight: headerHeight,
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Nombre del curso')),
        DataColumn(label: Text('Tipo')),
        DataColumn(label: Text('Carga horaria')),
        DataColumn(
          numeric: true,
          label: Text('Colaboradores'),
          tooltip:
              'Colaboradores distintos que declararon horas en el CRM '
              '(en los cursos de dictado, quienes lo dictaron)',
        ),
        DataColumn(
          numeric: true,
          label: Text('Horas CRM'),
          tooltip: 'Horas declaradas en el CRM para el curso',
        ),
        DataColumn(
          numeric: true,
          label: Text('Promedio por colaborador'),
          tooltip: 'Horas CRM / colaboradores. Comparalo con la carga horaria',
        ),
        DataColumn(
          numeric: true,
          label: Text('Finalizaron (LMS)'),
          tooltip: 'Colaboradores distintos con la finalización en el LMS',
        ),
      ],
      rows: [
        for (final stats in courses)
          DataRow(
            cells: [
              DataCell(
                Text(
                  stats.course.id,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              DataCell(
                Text(
                  stats.course.name,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              DataCell(
                stats.lmsCategory == null
                    ? Text('—', style: TextStyle(color: cs.onSurfaceVariant))
                    : CourseCategoryChip(type: stats.lmsCategory!),
              ),
              DataCell(
                Text(
                  '${formatHours(stats.course.workloadHours)} hs',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              DataCell(_MetricCell('${stats.people}', stats.people == 0)),
              DataCell(
                _MetricCell(
                  '${formatHours(stats.crmHours)} hs',
                  stats.people == 0,
                ),
              ),
              DataCell(
                _MetricCell(
                  stats.averageHoursPerPerson == null
                      ? '—'
                      : '${formatHoursPrecise(stats.averageHoursPerPerson!)} hs',
                  stats.averageHoursPerPerson == null,
                ),
              ),
              DataCell(_MetricCell('${stats.completed}', stats.completed == 0)),
            ],
          ),
      ],
    );
  }
}

/// Zeros go in grey, so courses nobody took stand out.
class _MetricCell extends StatelessWidget {
  final String text;
  final bool empty;

  const _MetricCell(this.text, this.empty);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Text(
      text,
      style: context.textTheme.bodySmall?.copyWith(
        fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
        color: empty ? cs.onSurfaceVariant : cs.onSurface,
      ),
    );
  }
}
