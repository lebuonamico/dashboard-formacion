import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/formatting/date_formatter.dart';
import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/kpi_grid.dart';
import 'package:app_finnegans/core/widgets/paginated_table.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/certifications/domain/certification_record.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/courses/presentation/widgets/course_category_chip.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          Expanded(
            child: Padding(
              padding: screenPadding,
              child: completeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorDataState(
                  title: 'No pudimos cargar las certificaciones LMS',
                  error: error,
                  onRetry: () => ref.invalidate(joinedCertificationsProvider),
                ),
                data: (all) => FadeIn(
                  child: all.isEmpty
                      ? const SingleChildScrollView(
                          child: EmptyDataState(
                            icon: Icons.menu_book_outlined,
                            title: 'No hay certificaciones LMS cargadas.',
                            message:
                                'Importá el Excel de finalizaciones del LMS.',
                          ),
                        )
                      : const _CertificationsContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificationsContent extends ConsumerWidget {
  const _CertificationsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(certificationKpisProvider).value;
    final totalPayroll = ref.watch(employeesProvider).value?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kpis != null) ...[
          KpiGrid(items: _kpis(context, kpis, totalPayroll)),
          const SizedBox(height: 20),
        ],
        const _CertificationsFilterBar(),
        const SizedBox(height: 20),
        Expanded(
          child: ref
              .watch(filteredCertificationsProvider)
              .when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorDataState(
                  title: 'No pudimos filtrar las certificaciones LMS',
                  error: error,
                  onRetry: () => ref.invalidate(filteredCertificationsProvider),
                ),
                data: (filtered) => filtered.isEmpty
                    ? const SingleChildScrollView(
                        child: EmptyDataState(
                          icon: Icons.search_off_outlined,
                          title:
                              'Ninguna certificación coincide con los filtros.',
                          message: 'Probá con otra búsqueda o estado.',
                        ),
                      )
                    : PaginatedTable(
                        items: filtered,
                        rowHeight: _CertificationsTable.rowHeight,
                        headerHeight: _CertificationsTable.headerHeight,
                        minimumWidth: 1000,
                        resultsLabel: 'certificaciones',
                        icon: Icons.workspace_premium_outlined,
                        tableBuilder: _CertificationsTable.new,
                      ),
              ),
        ),
      ],
    );
  }

  /// The KPIs summarize everything imported, not what the filters show.
  List<KpiData> _kpis(
    BuildContext context,
    CertificationKpis kpis,
    int totalPayroll,
  ) {
    final colors = context.colors;
    final CertificationKpis(
      :total,
      :completed,
      :pending,
      :outsideCalculation,
      :certifiedEmployees,
      :completedPercentage,
    ) = kpis;

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

class _CertificationsTable extends StatelessWidget {
  /// Two-line rows: employee and ID, area and team.
  static const rowHeight = 56.0;
  static const headerHeight = 44.0;

  final List<CertificationRecord> certifications;

  const _CertificationsTable(this.certifications);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return DataTable(
      showCheckboxColumn: false,
      columnSpacing: 24,
      headingRowHeight: headerHeight,
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
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
        for (final record in certifications)
          DataRow(
            // An employee ID outside the payroll has no profile to open.
            onSelectChanged: record.employeeIdOutsidePayroll
                ? null
                : (_) => context.push(
                    '/empleados/${Uri.encodeComponent(record.certification.employeeId)}'
                    '?origen=certificaciones',
                  ),
            cells: [
              DataCell(_EmployeeCell(record)),
              DataCell(_AreaTeamCell(record)),
              DataCell(_CourseCell(record)),
              DataCell(
                record.lmsCategory == null
                    ? Text('-', style: TextStyle(color: cs.onSurfaceVariant))
                    : CourseCategoryChip(type: record.lmsCategory!),
              ),
              DataCell(
                Text(
                  record.course == null
                      ? '-'
                      : '${record.course!.workloadHours.toStringAsFixed(0)} hs',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: record.course == null
                        ? cs.onSurfaceVariant
                        : cs.onSurface,
                  ),
                ),
              ),
              DataCell(_DateCell(record.certification.completedAt)),
              DataCell(
                ColorLabel(
                  text: record.certification.isCompleted
                      ? 'Finalizado'
                      : 'Pendiente',
                  colors: record.certification.isCompleted
                      ? context.colors.success
                      : context.colors.warning,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EmployeeCell extends StatelessWidget {
  final CertificationRecord record;

  const _EmployeeCell(this.record);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final employee = record.employee;
    final employeeId = record.certification.employeeId;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: cs.outlineVariant,
          child: Text(
            employee == null || employee.firstName.isEmpty
                ? '?'
                : employee.firstName.substring(0, 1),
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Flexible, not Expanded: keeps the notice next to the text, as in the
        // course column, instead of at the edge of the column.
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee == null
                    ? 'Legajo $employeeId'
                    : '${employee.firstName} ${employee.lastName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                employee == null ? 'Fuera de la nómina' : 'Legajo $employeeId',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: employee == null
                      ? context.colors.warning.text
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (record.employeeIdOutsidePayroll)
          const _Notice(_employeeOutsidePayrollNotice),
      ],
    );
  }
}

class _AreaTeamCell extends StatelessWidget {
  final CertificationRecord record;

  const _AreaTeamCell(this.record);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final employee = record.employee;
    if (employee == null) {
      return Text('-', style: TextStyle(color: cs.onSurfaceVariant));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          orDash(employee.area),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.intermediateText,
          ),
        ),
        Text(
          orDash(employee.team),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CourseCell extends StatelessWidget {
  final CertificationRecord record;

  const _CourseCell(this.record);

  @override
  Widget build(BuildContext context) {
    final name = record.course?.name ?? record.certification.courseName;
    return Row(
      children: [
        Flexible(
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
        if (record.courseOutsideCatalog)
          const _Notice(_courseOutsideCatalogNotice),
      ],
    );
  }
}

class _DateCell extends StatelessWidget {
  final DateTime? date;

  const _DateCell(this.date);

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    return Text(
      date == null ? '—' : formatDate(date),
      style: context.textTheme.bodySmall?.copyWith(
        color: date == null
            ? context.colors.faintText
            : context.colors.intermediateText,
      ),
    );
  }
}

/// Amber icon that explains why a certification does not count.
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
