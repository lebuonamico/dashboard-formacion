import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/period/presentation/optional_period_filter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/adaptive_record_list.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/info_hint.dart';
import 'package:app_finnegans/core/widgets/list_screen_body.dart';
import 'package:app_finnegans/core/widgets/paginated_table.dart';
import 'package:app_finnegans/core/widgets/record_card.dart';
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
            child: ListScreenBody(
              header: const [_CoursesFilterBar(), SizedBox(height: 20)],
              results: coursesAsync.when(
                skipLoadingOnReload: true,
                loading: () => const ListLoading(),
                error: (err, _) => ErrorDataState(
                  title: 'No pudimos cargar los cursos',
                  error: err,
                  onRetry: () => ref.invalidate(courseStatsProvider),
                ),
                data: (courses) => FadeIn(
                  child: courses.isEmpty
                      ? const _NoCourses()
                      : _CoursesList(courses),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What each metric counts: the table's header tooltips and, below 840 px,
/// the help above the cards.
const _peopleHelp =
    'Colaboradores distintos que declararon horas en el CRM '
    '(en los cursos de dictado, quienes lo dictaron)';
const _crmHoursHelp = 'Horas declaradas en el CRM para el curso';
const _averageHelp =
    'Horas CRM / colaboradores. Comparalo con la carga horaria';
const _completedHelp = 'Colaboradores distintos con la finalización en el LMS';

class _CoursesList extends StatelessWidget {
  final List<CourseStats> courses;

  const _CoursesList(this.courses);

  @override
  Widget build(BuildContext context) {
    final list = AdaptiveRecordList(
      items: courses,
      resultsLabel: 'cursos',
      icon: Icons.school_outlined,
      table: (items) => PaginatedTable(
        items: items,
        rowHeight: _CoursesTable.rowHeight,
        headerHeight: _CoursesTable.headerHeight,
        resultsLabel: 'cursos',
        icon: Icons.school_outlined,
        tableBuilder: _CoursesTable.new,
      ),
      card: (stats) => _CourseCard(stats),
    );
    if (context.windowSize == WindowSize.expanded) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const _MetricsHelp(), const SizedBox(height: 12), list],
    );
  }
}

/// Below 840 px, the table's header tooltips in a single tap-to-read hint.
class _MetricsHelp extends StatelessWidget {
  const _MetricsHelp();

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('course_metrics_help'),
    children: [
      Flexible(
        child: Text(
          '¿Qué mide cada número?',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(width: 6),
      const InfoHint(
        message:
            'Colaboradores: $_peopleHelp.\n'
            'Horas CRM: $_crmHoursHelp.\n'
            'Promedio por colaborador: $_averageHelp.\n'
            'Finalizaron (LMS): $_completedHelp.',
      ),
    ],
  );
}

/// Below 840 px: what a row of the table shows.
class _CourseCard extends StatelessWidget {
  final CourseStats stats;

  const _CourseCard(this.stats);

  @override
  Widget build(BuildContext context) {
    final category = stats.lmsCategory;
    final average = stats.averageHoursPerPerson;
    return RecordCard(
      key: ValueKey('course_card_${stats.course.id}'),
      title: stats.course.name,
      subtitle: 'ID ${stats.course.id}',
      trailing: category == null ? null : CourseCategoryChip(type: category),
      metrics: [
        if (category == null) const RecordMetric('Tipo', '—', muted: true),
        RecordMetric(
          'Carga horaria',
          '${formatHours(stats.course.workloadHours)} hs',
        ),
        RecordMetric(
          'Colaboradores',
          '${stats.people}',
          muted: stats.people == 0,
        ),
        RecordMetric(
          'Horas CRM',
          '${formatHours(stats.crmHours)} hs',
          muted: stats.people == 0,
        ),
        RecordMetric(
          'Promedio por colaborador',
          average == null ? '—' : '${formatHoursPrecise(average)} hs',
          muted: average == null,
        ),
        RecordMetric(
          'Finalizaron (LMS)',
          '${stats.completed}',
          muted: stats.completed == 0,
        ),
      ],
    );
  }
}

/// Tells "nothing imported" apart from "nothing matches the filters".
class _NoCourses extends ConsumerWidget {
  const _NoCourses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCourses = ref.watch(coursesProvider).value?.isNotEmpty ?? false;
    return ListEmptyState(
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
      activeExtraFilters: [period.year, period.month].nonNulls.length,
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
          tooltip: _peopleHelp,
        ),
        DataColumn(
          numeric: true,
          label: Text('Horas CRM'),
          tooltip: _crmHoursHelp,
        ),
        DataColumn(
          numeric: true,
          label: Text('Promedio por colaborador'),
          tooltip: _averageHelp,
        ),
        DataColumn(
          numeric: true,
          label: Text('Finalizaron (LMS)'),
          tooltip: _completedHelp,
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
