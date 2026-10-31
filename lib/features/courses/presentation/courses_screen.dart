import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/period/presentation/optional_period_filter.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/courses/presentation/widgets/course_category_chip.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
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

          // Contenido
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
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => ErrorDataState(
                        title: 'No pudimos cargar los cursos',
                        error: err,
                      ),
                      data: (coursesList) => FadeIn(
                        child: (() {
                          if (coursesList.isEmpty) {
                            final hasCourses =
                                ref.watch(coursesProvider).value?.isNotEmpty ??
                                false;
                            return SingleChildScrollView(
                              child: hasCourses
                                  ? const EmptyDataState(
                                      icon: Icons.search_off_outlined,
                                      title:
                                          'No se encontraron cursos con los filtros aplicados.',
                                      message:
                                          'Probá con otra búsqueda o tipo de curso.',
                                    )
                                  : const EmptyDataState(
                                      icon: Icons.menu_book_outlined,
                                      title: 'No hay cursos cargados.',
                                      message:
                                          'Importá el catálogo de cursos o sincronizalo desde Moodle.',
                                    ),
                            );
                          }
                          return _PaginatedCoursesTable(courses: coursesList);
                        })(),
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

/// Tabla del catálogo, de a una página por vez, para no tener que scrollear.
class _PaginatedCoursesTable extends StatefulWidget {
  final List<CourseViewModel> courses;

  const _PaginatedCoursesTable({required this.courses});

  @override
  State<_PaginatedCoursesTable> createState() => _PaginatedCoursesTableState();
}

class _PaginatedCoursesTableState extends State<_PaginatedCoursesTable> {
  static const _rowHeight = 44.0;
  static const _headerHeight = 44.0;
  static const _paginatorHeight = 60.0;
  static const _spacing = 12.0;

  /// Mínimo razonable si la ventana queda muy baja.
  static const _minimumPerPage = 5;

  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant _PaginatedCoursesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar el filtro o la búsqueda, volver a la primera página.
    if (oldWidget.courses != widget.courses) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.courses.length;

        // Cuántas filas entran en el alto que nos dieron. Así la tabla llena la
        // página y no queda un hueco entre la última fila y el paginador.
        final heightForTable =
            constraints.maxHeight - _paginatorHeight - _spacing;
        final coursesPerPage = ((heightForTable - _headerHeight) / _rowHeight)
            .floor()
            .clamp(
              _minimumPerPage,
              // Nunca más filas que cursos hay.
              total < _minimumPerPage ? _minimumPerPage : total,
            );

        final totalPages = total == 0
            ? 1
            : (total + coursesPerPage - 1) ~/ coursesPerPage;
        final safePage = _currentPage.clamp(0, totalPages - 1);
        final start = safePage * coursesPerPage;
        final calculatedEnd = start + coursesPerPage;
        final end = calculatedEnd > total ? total : calculatedEnd;
        final visible = widget.courses.sublist(start, end);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sin recuadro: la tabla se dibuja directo sobre la página y ocupa
            // todo el ancho disponible.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  // Red de seguridad por si algo no entra.
                  child: SingleChildScrollView(child: _table(visible)),
                ),
              ),
            ),
            if (totalPages > 1) ...[
              const SizedBox(height: _spacing),
              ResultsPagination(
                currentPage: safePage,
                pageCount: totalPages,
                from: start + 1,
                until: end,
                totalResults: total,
                resultsLabel: 'cursos',
                icon: Icons.school_outlined,
                onPrevious: safePage > 0
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null,
                onNext: safePage < totalPages - 1
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _table(List<CourseViewModel> visible) {
    final cs = context.colorScheme;
    // Encabezados, divisores y márgenes salen del dataTableTheme.
    return DataTable(
      columnSpacing: 24,
      // Filas más compactas: entran más cursos sin que se vea apretado.
      headingRowHeight: _headerHeight,
      dataRowMinHeight: _rowHeight,
      dataRowMaxHeight: _rowHeight,
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Nombre del curso')),
        DataColumn(label: Text('Tipo')),
        DataColumn(label: Text('Carga horaria')),
        DataColumn(
          numeric: true,
          label: Text('Personas'),
          tooltip:
              'Colaboradores distintos que cargaron horas en el CRM '
              '(en los cursos de dictado, quienes lo dictaron)',
        ),
        DataColumn(
          numeric: true,
          label: Text('Horas CRM'),
          tooltip: 'Horas cargadas en el CRM para el curso',
        ),
        DataColumn(
          numeric: true,
          label: Text('Promedio por persona'),
          tooltip: 'Horas CRM / personas. Comparalo con la carga horaria',
        ),
        DataColumn(
          numeric: true,
          label: Text('Finalizaron (LMS)'),
          tooltip: 'Colaboradores distintos con la finalización en el LMS',
        ),
      ],
      rows: [
        for (final vm in visible)
          DataRow(
            cells: [
              // El ID es dato secundario: va en gris para que no le compita al
              // nombre del curso.
              DataCell(
                Text(
                  vm.course.id,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              DataCell(
                Text(
                  vm.course.name,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              DataCell(
                vm.course.classificationLms == null
                    ? const Text('-')
                    : CourseCategoryChip(type: vm.course.classificationLms!),
              ),
              DataCell(
                Text(
                  '${vm.course.workloadHours.toStringAsFixed(0)} hs',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              DataCell(_metricCell('${vm.people}', vm.people == 0)),
              DataCell(
                _metricCell('${_hoursFormat(vm.crmHours)} hs', vm.people == 0),
              ),
              DataCell(
                _metricCell(
                  vm.averageHoursPerPerson == null
                      ? '—'
                      : '${_hoursFormat(vm.averageHoursPerPerson!)} hs',
                  vm.averageHoursPerPerson == null,
                ),
              ),
              DataCell(_metricCell('${vm.completed}', vm.completed == 0)),
            ],
          ),
      ],
    );
  }

  /// Los ceros van en gris: así se ve de un vistazo qué cursos no tomó nadie.
  Widget _metricCell(String text, bool empty) {
    final cs = context.colorScheme;
    return Text(
      text,
      style: context.textTheme.bodySmall?.copyWith(
        fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
        color: empty ? cs.onSurfaceVariant : cs.onSurface,
      ),
    );
  }

  /// Sin decimales si son horas enteras, con uno si no.
  static String _hoursFormat(double hours) => hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
}
