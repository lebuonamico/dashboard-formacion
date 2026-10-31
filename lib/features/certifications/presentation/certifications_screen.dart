import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/widgets/kpi_grid.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/courses/presentation/widgets/course_category_chip.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';

const _courseOutsideCatalogNotice =
    'El curso no está en el catálogo: esta finalización no acredita horas.';
const _employeeOutsidePayrollNotice =
    'El legajo no está en la nómina: no suma al cumplimiento de ningún equipo.';

class CertificationsScreen extends ConsumerWidget {
  const CertificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completeAsync = ref.watch(joinedCertificationsProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Certificaciones LMS'),

          // Contenido
          Expanded(
            child: Padding(
              padding: screenPadding,
              child: completeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorDataState(
                  title: 'No pudimos cargar las certificaciones LMS',
                  error: error,
                ),
                data: (all) => FadeIn(
                  child: (() {
                    if (all.isEmpty) {
                      return const SingleChildScrollView(
                        child: EmptyDataState(
                          icon: Icons.menu_book_outlined,
                          title: 'No hay certificaciones LMS cargadas.',
                          message:
                              'Importá el Excel de finalizaciones del LMS.',
                        ),
                      );
                    }

                    final filtered =
                        ref.watch(filteredCertificationsProvider).value ??
                        const <CertificationViewModel>[];
                    final totalPayroll =
                        ref.watch(employeesProvider).value?.length ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KpiGrid(items: _kpis(context, all, totalPayroll)),
                        const SizedBox(height: 20),
                        const _CertificationsFilterBar(),
                        const SizedBox(height: 20),
                        Expanded(
                          child: filtered.isEmpty
                              ? const SingleChildScrollView(
                                  child: EmptyDataState(
                                    icon: Icons.search_off_outlined,
                                    title:
                                        'Ninguna certificación coincide con los filtros.',
                                    message:
                                        'Probá con otra búsqueda o estado.',
                                  ),
                                )
                              : _PaginatedCertificationsTable(
                                  certifications: filtered,
                                ),
                        ),
                      ],
                    );
                  })(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Los KPIs resumen todo lo importado, no lo que dejan ver los filtros.
  List<KpiData> _kpis(
    BuildContext context,
    List<CertificationViewModel> all,
    int totalPayroll,
  ) {
    final colors = context.colors;
    final total = all.length;
    final completed = all.where((vm) => vm.certification.isCompleted).length;
    final pending = total - completed;
    final outsideCalculation = all.where((vm) => vm.outsideCalculation).length;
    final certifiedEmployees = {
      for (final vm in all)
        if (vm.certification.isCompleted && !vm.employeeIdOutsidePayroll)
          vm.certification.employeeId,
    }.length;
    final completedPercentage = total == 0 ? 0 : completed / total * 100;

    return [
      KpiData(
        title: 'Registros',
        value: '$total',
        detail: outsideCalculation == 0
            ? 'todos cruzan con nómina y catálogo'
            : '$outsideCalculation fuera del cálculo',
        help:
            'Certificaciones importadas del LMS. Las que tienen un curso fuera '
            'del catálogo o un legajo fuera de la nómina no acreditan horas.',
        icon: Icons.fact_check_outlined,
        color: context.colorScheme.primary,
      ),
      KpiData(
        title: 'Finalizadas',
        value: '$completed',
        detail: '${completedPercentage.toStringAsFixed(0)}% del total',
        help: 'Certificaciones con el curso finalizado en el LMS.',
        icon: Icons.task_alt,
        color: colors.success.text,
      ),
      KpiData(
        title: 'Pendientes',
        value: '$pending',
        detail: 'sin finalización en el LMS',
        help:
            'Certificaciones importadas que todavía no tienen el curso '
            'finalizado en el LMS. No acreditan horas.',
        icon: Icons.pending_actions_outlined,
        color: colors.warning.text,
      ),
      KpiData(
        title: 'Colaboradores certificados',
        value: '$certifiedEmployees',
        detail: 'de $totalPayroll en la nómina',
        help: 'Colaboradores de la nómina con al menos un curso finalizado.',
        icon: Icons.workspace_premium_outlined,
        color: colors.violetAccent,
      ),
    ];
  }
}

class _CertificationsFilterBar extends ConsumerWidget {
  const _CertificationsFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilterBar(
    scope: DataFilterScope.certifications,
    rows: ref.watch(certificationFilterRowsProvider),
  );
}

/// Tabla de certificaciones, de a una página por vez y a todo el ancho.
class _PaginatedCertificationsTable extends StatefulWidget {
  final List<CertificationViewModel> certifications;

  const _PaginatedCertificationsTable({required this.certifications});

  @override
  State<_PaginatedCertificationsTable> createState() =>
      _PaginatedCertificationsTableState();
}

class _PaginatedCertificationsTableState
    extends State<_PaginatedCertificationsTable> {
  // Filas de dos líneas: colaborador + legajo y área + equipo.
  static const _rowHeight = 56.0;
  static const _headerHeight = 44.0;
  static const _paginatorHeight = 60.0;
  static const _spacing = 12.0;

  /// Debajo de este ancho las columnas se aprietan demasiado: aparece el
  /// scroll horizontal en lugar de cortar todos los textos.
  static const _minimumWidth = 1000.0;

  /// Mínimo razonable si la ventana queda muy baja.
  static const _minimumPerPage = 5;

  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant _PaginatedCertificationsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar el filtro o la búsqueda, volver a la primera página.
    if (oldWidget.certifications != widget.certifications) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.certifications.length;

        // Cuántas filas entran en el alto disponible, para que la tabla llene
        // la página sin dejar un hueco antes del paginador.
        final heightForTable =
            constraints.maxHeight - _paginatorHeight - _spacing;
        final perPage = ((heightForTable - _headerHeight) / _rowHeight)
            .floor()
            .clamp(
              _minimumPerPage,
              total < _minimumPerPage ? _minimumPerPage : total,
            );

        final totalPages = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
        final safePage = _currentPage.clamp(0, totalPages - 1);
        final start = safePage * perPage;
        final calculatedEnd = start + perPage;
        final end = calculatedEnd > total ? total : calculatedEnd;
        final visible = widget.certifications.sublist(start, end);

        // Ancho fijo (no un mínimo): las columnas flex necesitan un ancho
        // acotado para repartirse, si no colapsan dentro del scroll.
        final width = constraints.maxWidth < _minimumWidth
            ? _minimumWidth
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
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
                resultsLabel: 'certificaciones',
                icon: Icons.workspace_premium_outlined,
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

  Widget _table(List<CertificationViewModel> visible) {
    final cs = context.colorScheme;
    // Encabezados, divisores y márgenes salen del dataTableTheme.
    return DataTable(
      showCheckboxColumn: false,
      columnSpacing: 24,
      headingRowHeight: _headerHeight,
      dataRowMinHeight: _rowHeight,
      dataRowMaxHeight: _rowHeight,
      // Proporciones del ancho: el curso y el colaborador son lo que más se
      // lee, la carga horaria y la fecha son datos cortos.
      columns: const [
        DataColumn(columnWidth: FlexColumnWidth(3), label: Text('Colaborador')),
        DataColumn(
          columnWidth: FlexColumnWidth(2.5),
          label: Text('Área / Equipo'),
        ),
        DataColumn(columnWidth: FlexColumnWidth(3.5), label: Text('Curso')),
        DataColumn(columnWidth: FlexColumnWidth(2), label: Text('Tipo')),
        DataColumn(
          columnWidth: FlexColumnWidth(1.2),
          label: Text('Carga horaria'),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.5),
          label: Text('Finalización'),
        ),
        DataColumn(columnWidth: FlexColumnWidth(1.5), label: Text('Estado')),
      ],
      rows: [
        for (final vm in visible)
          DataRow(
            // Abre el perfil del colaborador. Un legajo fuera de la nómina no
            // tiene perfil: la fila no responde al click.
            onSelectChanged: vm.employeeIdOutsidePayroll
                ? null
                : (_) => context.push(
                    '/empleados/${Uri.encodeComponent(vm.certification.employeeId)}'
                    '?origen=certificaciones',
                  ),
            cells: [
              DataCell(_employeeCell(vm)),
              DataCell(_areaTeamCell(vm)),
              DataCell(_courseCell(vm)),
              DataCell(
                vm.course?.classificationLms == null
                    ? Text('-', style: TextStyle(color: cs.onSurfaceVariant))
                    : CourseCategoryChip(type: vm.course!.classificationLms!),
              ),
              DataCell(
                Text(
                  vm.course == null
                      ? '-'
                      : '${vm.course!.workloadHours.toStringAsFixed(0)} hs',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: vm.course == null
                        ? cs.onSurfaceVariant
                        : cs.onSurface,
                  ),
                ),
              ),
              DataCell(_dateCell(vm.certification.completedAt)),
              DataCell(_status(vm.certification.isCompleted)),
            ],
          ),
      ],
    );
  }

  /// Estado con los colores del semáforo: verde finalizado, ámbar pendiente.
  Widget _status(bool completed) => ColorLabel(
    text: completed ? 'Finalizado' : 'Pendiente',
    colors: completed ? context.colors.success : context.colors.warning,
  );

  Widget _employeeCell(CertificationViewModel vm) {
    final cs = context.colorScheme;
    final emp = vm.employee;
    final employeeId = vm.certification.employeeId;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: cs.outlineVariant,
          child: Text(
            emp == null || emp.firstName.isEmpty
                ? '?'
                : emp.firstName.substring(0, 1),
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Flexible y no Expanded: el aviso queda pegado al texto, igual que en
        // la columna Curso, en lugar de irse al borde de la columna.
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emp == null
                    ? 'Legajo $employeeId'
                    : '${emp.firstName} ${emp.lastName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                emp == null ? 'Fuera de la nómina' : 'Legajo $employeeId',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: emp == null
                      ? context.colors.warning.text
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (vm.employeeIdOutsidePayroll)
          const _Notice(_employeeOutsidePayrollNotice),
      ],
    );
  }

  Widget _areaTeamCell(CertificationViewModel vm) {
    final cs = context.colorScheme;
    final emp = vm.employee;
    if (emp == null) {
      return Text('-', style: TextStyle(color: cs.onSurfaceVariant));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _showData(emp.area),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.intermediateText,
          ),
        ),
        Text(
          _showData(emp.team),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _courseCell(CertificationViewModel vm) {
    final name = vm.course?.name ?? vm.certification.courseName;

    return Row(
      children: [
        Flexible(
          // El nombre se corta con puntos suspensivos; el tooltip muestra el
          // nombre completo.
          child: Tooltip(
            message: name,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        if (vm.courseOutsideCatalog) const _Notice(_courseOutsideCatalogNotice),
      ],
    );
  }

  Widget _dateCell(DateTime? date) {
    return Text(
      date == null ? '—' : _formatDate(date),
      style: context.textTheme.bodySmall?.copyWith(
        color: date == null
            ? context.colors.faintText
            : context.colors.intermediateText,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _showData(String value) => value.trim().isEmpty ? '-' : value;
}

/// Ícono ámbar que avisa por qué una certificación no entra al cumplimiento.
class _Notice extends StatelessWidget {
  final String message;

  const _Notice(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: message,
        child: Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: context.colors.warning.text,
        ),
      ),
    );
  }
}
