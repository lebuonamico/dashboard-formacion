import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/formatting/date_formatter.dart';
import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:app_finnegans/core/period/presentation/optional_period_filter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/paginated_table.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry_record.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TimeEntriesScreen extends ConsumerWidget {
  const TimeEntriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeEntriesAsync = ref.watch(joinedTimeEntriesProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Carga de horas CRM'),
          Expanded(
            child: Padding(
              padding: screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BarFiltersCrm(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: timeEntriesAsync.when(
                      skipLoadingOnReload: true,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => ErrorDataState(
                        title: 'No pudimos cargar las horas CRM',
                        error: err,
                        onRetry: () =>
                            ref.invalidate(joinedTimeEntriesProvider),
                      ),
                      data: (items) => FadeIn(
                        child: items.isEmpty
                            ? const _NoTimeEntries()
                            : PaginatedTable(
                                items: items,
                                rowHeight: _TimeEntriesTable.rowHeight,
                                headerHeight: _TimeEntriesTable.headerHeight,
                                minimumWidth: 1000,
                                resultsLabel: 'registros',
                                icon: Icons.schedule_outlined,
                                tableBuilder: _TimeEntriesTable.new,
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
class _NoTimeEntries extends ConsumerWidget {
  const _NoTimeEntries();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTimeEntries =
        ref.watch(crmTimeEntriesProvider).value?.isNotEmpty ?? false;
    return SingleChildScrollView(
      child: hasTimeEntries
          ? const EmptyDataState(
              icon: Icons.search_off_outlined,
              title: 'Ninguna carga de horas coincide con los filtros.',
              message: 'Probá con otros filtros.',
            )
          : const EmptyDataState(
              icon: Icons.schedule_outlined,
              title: 'No hay horas CRM cargadas.',
              message: 'Importá el reporte de horas del CRM.',
            ),
    );
  }
}

class _BarFiltersCrm extends ConsumerWidget {
  const _BarFiltersCrm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(timeEntriesPeriodProvider);
    return FilterBar(
      scope: DataFilterScope.timeEntries,
      rows: ref.watch(timeEntryFilterRowsProvider),
      extraFilters: [
        OptionalYearFilter(
          provider: timeEntriesPeriodProvider,
          availableYears:
              ref.watch(availableTimeEntryYearsProvider).value ?? const [],
          width: 220,
        ),
        OptionalMonthFilter(provider: timeEntriesPeriodProvider, width: 240),
      ],
      hasActiveExtraFilters: period.year != null || period.month != null,
      onClearExtraFilters: ref.read(timeEntriesPeriodProvider.notifier).clear,
    );
  }
}

class _TimeEntriesTable extends StatelessWidget {
  /// Two-line rows: employee and ID, area and team.
  static const rowHeight = 56.0;
  static const headerHeight = 44.0;

  final List<CrmTimeEntryRecord> timeEntries;

  const _TimeEntriesTable(this.timeEntries);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final secondary = context.textTheme.labelMedium!.copyWith(
      color: cs.onSurfaceVariant,
    );
    return DataTable(
      showCheckboxColumn: false,
      columnSpacing: 24,
      headingRowHeight: headerHeight,
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      columns: const [
        DataColumn(columnWidth: FlexColumnWidth(1.2), label: Text('Fecha')),
        DataColumn(columnWidth: FlexColumnWidth(3), label: Text('Colaborador')),
        DataColumn(
          columnWidth: FlexColumnWidth(2.5),
          label: Text('Área / Equipo'),
        ),
        DataColumn(columnWidth: FlexColumnWidth(1.6), label: Text('Seniority')),
        DataColumn(columnWidth: FlexColumnWidth(3.5), label: Text('Curso')),
        DataColumn(columnWidth: FlexColumnWidth(1.5), label: Text('Horas CRM')),
        DataColumn(
          columnWidth: FlexColumnWidth(1.3),
          label: Text('ID registro'),
        ),
      ],
      rows: [
        for (final record in timeEntries)
          DataRow(
            // An employee ID outside the payroll has no profile to open.
            onSelectChanged: record.employee == null
                ? null
                : (_) => context.push(
                    '/empleados/${Uri.encodeComponent(record.timeEntry.employeeId)}'
                    '?origen=cursadas',
                  ),
            cells: [
              DataCell(
                Text(
                  formatDate(record.timeEntry.date),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.intermediateText,
                  ),
                ),
              ),
              DataCell(_EmployeeCell(record)),
              DataCell(_AreaTeamCell(record)),
              DataCell(
                record.employee == null
                    ? Text('—', style: TextStyle(color: cs.onSurfaceVariant))
                    : SeniorityChip(seniority: record.employee!.seniority),
              ),
              DataCell(_CourseCell(record)),
              DataCell(_HoursCell(record)),
              DataCell(
                Text(
                  record.timeEntry.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EmployeeCell extends StatelessWidget {
  final CrmTimeEntryRecord record;

  const _EmployeeCell(this.record);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final employee = record.employee;
    final employeeId = record.timeEntry.employeeId;

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
        Expanded(
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
      ],
    );
  }
}

class _AreaTeamCell extends StatelessWidget {
  final CrmTimeEntryRecord record;

  const _AreaTeamCell(this.record);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final employee = record.employee;
    if (employee == null) {
      return Text('—', style: TextStyle(color: cs.onSurfaceVariant));
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
  final CrmTimeEntryRecord record;

  const _CourseCell(this.record);

  @override
  Widget build(BuildContext context) {
    final name = record.course?.name ?? record.timeEntry.courseName;
    return Tooltip(
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
    );
  }
}

class _HoursCell extends StatelessWidget {
  final CrmTimeEntryRecord record;

  const _HoursCell(this.record);

  @override
  Widget build(BuildContext context) {
    final success = context.colors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: success.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${formatDecimal(record.timeEntry.hours, digits: 2)} hs'
        '${record.isTaught ? ' (dictadas)' : ' (tomadas)'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.labelMedium?.copyWith(
          color: success.text,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
