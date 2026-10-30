import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/period/period_formatter.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/data_filters/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/filter_dropdown.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimeEntriesScreen extends ConsumerWidget {
  const TimeEntriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeEntriesAsync = ref.watch(joinedTimeEntriesProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Carga de horas CRM'),

          // Contenido
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
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => ErrorDataState(
                        title: 'No pudimos cargar las horas CRM',
                        error: err,
                      ),
                      data: (items) => FadeIn(
                        child: (() {
                          if (items.isEmpty) {
                            final hasTimeEntries =
                                ref
                                    .watch(crmTimeEntriesProvider)
                                    .value
                                    ?.isNotEmpty ??
                                false;
                            return SingleChildScrollView(
                              child: hasTimeEntries
                                  ? const EmptyDataState(
                                      icon: Icons.search_off_outlined,
                                      title:
                                          'Ninguna carga de horas coincide con los filtros.',
                                      message:
                                          'Probá con otra búsqueda, período o área.',
                                    )
                                  : const EmptyDataState(
                                      icon: Icons.schedule_outlined,
                                      title: 'No hay horas CRM cargadas.',
                                      message:
                                          'Importá el reporte de horas del CRM.',
                                    ),
                            );
                          }
                          return _PaginatedTimeEntriesTable(timeEntries: items);
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

/// Buscador por texto (colaborador, legajo, curso o área) y desplegables de
/// año y mes.
class _BarFiltersCrm extends ConsumerWidget {
  const _BarFiltersCrm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(timeEntrySearchProvider);
    final year = ref.watch(timeEntryYearFilterProvider);
    final month = ref.watch(timeEntryMonthFilterProvider);
    final years = ref.watch(availableTimeEntryYearsProvider).value ?? const [];

    return FilterBar(
      scope: 'crm',
      hasActiveFilters: search.isNotEmpty || year != null || month != null,
      filters: [
        FilterDropdown<int?>(
          value: year,
          hint: 'Todos los años',
          icon: Icons.event_outlined,
          width: 220,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Todos los años'),
            ),
            // Si el año elegido ya no tiene cargas, se mantiene visible para
            // que el desplegable no quede con un valor inexistente.
            for (final a in {...years, ?year})
              DropdownMenuItem<int?>(value: a, child: Text('$a')),
          ],
          onChanged: (value) {
            ref.read(timeEntryYearFilterProvider.notifier).state = value;
          },
        ),
        FilterDropdown<int?>(
          value: month,
          hint: 'Todos los meses',
          icon: Icons.calendar_month_outlined,
          width: 240,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Todos los meses'),
            ),
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem<int?>(value: m, child: Text(monthName(m))),
          ],
          onChanged: (value) =>
              ref.read(timeEntryMonthFilterProvider.notifier).state = value,
        ),
      ],
      onClear: () {
        ref.read(timeEntrySearchProvider.notifier).state = '';
        ref.read(timeEntryYearFilterProvider.notifier).state = null;
        ref.read(timeEntryMonthFilterProvider.notifier).state = null;
      },
    );
  }
}

/// Tabla de cargas de horas, de a una página por vez y a todo el ancho.
class _PaginatedTimeEntriesTable extends StatefulWidget {
  final List<CrmTimeEntryViewModel> timeEntries;

  const _PaginatedTimeEntriesTable({required this.timeEntries});

  @override
  State<_PaginatedTimeEntriesTable> createState() =>
      _PaginatedTimeEntriesTableState();
}

class _PaginatedTimeEntriesTableState
    extends State<_PaginatedTimeEntriesTable> {
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
  void didUpdateWidget(covariant _PaginatedTimeEntriesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar un filtro o la búsqueda, volver a la primera página.
    if (oldWidget.timeEntries != widget.timeEntries) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.timeEntries.length;

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
        final visible = widget.timeEntries.sublist(start, end);

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
                resultsLabel: 'registros',
                icon: Icons.schedule_outlined,
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

  Widget _table(List<CrmTimeEntryViewModel> visible) {
    final cs = context.colorScheme;
    final secondary = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    // Encabezados, divisores y márgenes salen del dataTableTheme.
    return DataTable(
      columnSpacing: 24,
      headingRowHeight: _headerHeight,
      dataRowMinHeight: _rowHeight,
      dataRowMaxHeight: _rowHeight,
      // Proporciones del ancho: el curso y el colaborador son lo que más se
      // lee, la fecha y el ID son datos cortos.
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
        for (final vm in visible)
          DataRow(
            cells: [
              DataCell(
                Text(
                  _formatDate(vm.timeEntry.date),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.intermediateText,
                  ),
                ),
              ),
              DataCell(_employeeCell(vm)),
              DataCell(_areaTeamCell(vm)),
              DataCell(
                vm.employee == null
                    ? Text('-', style: TextStyle(color: cs.onSurfaceVariant))
                    : SeniorityChip(seniority: vm.employee!.seniority),
              ),
              DataCell(_courseCell(vm)),
              DataCell(_hoursCell(vm)),
              DataCell(
                Text(
                  vm.timeEntry.id,
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

  Widget _employeeCell(CrmTimeEntryViewModel vm) {
    final cs = context.colorScheme;
    final emp = vm.employee;
    final employeeId = vm.timeEntry.employeeId;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: cs.outlineVariant,
          child: Text(
            emp == null || emp.firstName.isEmpty
                ? '?'
                : emp.firstName.substring(0, 1),
            style: TextStyle(
              fontSize: 12,
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
                emp == null
                    ? 'Legajo $employeeId'
                    : '${emp.firstName} ${emp.lastName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                emp == null ? 'Fuera de la nómina' : 'Legajo $employeeId',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: emp == null
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

  Widget _areaTeamCell(CrmTimeEntryViewModel vm) {
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
          style: TextStyle(
            fontSize: 13,
            color: context.colors.intermediateText,
          ),
        ),
        Text(
          _showData(emp.team),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _courseCell(CrmTimeEntryViewModel vm) {
    final name = vm.course?.name ?? vm.timeEntry.courseName;

    // El nombre se corta con puntos suspensivos; el tooltip muestra el nombre
    // completo.
    return Tooltip(
      message: name,
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _hoursCell(CrmTimeEntryViewModel vm) {
    final timeEntry = vm.timeEntry;
    final success = context.colors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: success.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${timeEntry.hours.toStringAsFixed(2)} hs${timeEntry.isTaught ? ' (dictadas)' : ' (tomadas)'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: success.text,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
