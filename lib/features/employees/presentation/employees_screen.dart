import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/paginated_table.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/category_hours_progress.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredEmployees = ref.watch(filteredEmployeesProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Directorio de colaboradores'),
          Expanded(
            child: Padding(
              padding: screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The category progress is the selected period's, the
                  // same one the profile opens with.
                  const PeriodFilterPanel(
                    included:
                        'Se incluyen los colaboradores elegibles al cierre, '
                        'aunque tengan 0 horas.',
                  ),
                  const SizedBox(height: 20),
                  const _EmployeesFiltersBar(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: filteredEmployees.when(
                      skipLoadingOnReload: true,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => ErrorDataState(
                        title: 'No pudimos cargar los colaboradores',
                        error: err,
                        onRetry: () =>
                            ref.invalidate(filteredEmployeesProvider),
                      ),
                      data: (employees) =>
                          FadeIn(child: _EmployeesResults(employees)),
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

class _EmployeesFiltersBar extends ConsumerWidget {
  const _EmployeesFiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilterBar(
    scope: DataFilterScope.employees,
    rows: ref.watch(employeeFilterRowsProvider),
  );
}

class _EmployeesResults extends ConsumerWidget {
  final List<Employee> employees;

  const _EmployeesResults(this.employees);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (employees.isEmpty) {
      final hasPayroll =
          ref.watch(employeesProvider).value?.isNotEmpty ?? false;
      return SingleChildScrollView(
        child: hasPayroll
            ? const EmptyDataState(
                icon: Icons.search_off_outlined,
                title: 'Ningún colaborador coincide con los filtros.',
                message: 'Probá con otros filtros.',
              )
            : const EmptyDataState(
                icon: Icons.people_outline,
                title: 'No hay colaboradores cargados.',
                message: 'Importá la nómina para ver el directorio.',
              ),
      );
    }
    return ref
        .watch(teamComplianceProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _PaginatedEmployeesTable(
            employees: employees,
            complianceByEmployeeId: const {},
          ),
          data: (items) => _PaginatedEmployeesTable(
            employees: employees,
            complianceByEmployeeId: {
              for (final item in items) item.employee.employeeId: item,
            },
          ),
        );
  }
}

class _PaginatedEmployeesTable extends StatelessWidget {
  /// Below this width the table scrolls horizontally instead of truncating
  /// every text. Wider than the CRM table because the progress column has a
  /// fixed width.
  static const _minimumWidth = 1100.0;

  final List<Employee> employees;
  final Map<String, EmployeeCompliance> complianceByEmployeeId;

  const _PaginatedEmployeesTable({
    required this.employees,
    required this.complianceByEmployeeId,
  });

  @override
  Widget build(BuildContext context) => PaginatedTable(
    items: employees,
    rowHeight: _EmployeesTable.rowHeight,
    headerHeight: _EmployeesTable.headerHeight,
    minimumWidth: _minimumWidth,
    resultsLabel: 'colaboradores',
    icon: Icons.people_outline,
    tableBuilder: (visible) => _EmployeesTable(
      employees: visible,
      complianceByEmployeeId: complianceByEmployeeId,
    ),
  );
}

class _EmployeesTable extends StatelessWidget {
  /// Two-line rows: name and email, area and team, and the progress chips.
  static const rowHeight = 56.0;
  static const headerHeight = 44.0;

  /// [CategoryHoursProgress] chips are 256 px wide; the column adds the
  /// column spacing so they do not overflow.
  static const _progressWidth = 256.0 + 24.0;

  final List<Employee> employees;
  final Map<String, EmployeeCompliance> complianceByEmployeeId;

  const _EmployeesTable({
    required this.employees,
    required this.complianceByEmployeeId,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      showCheckboxColumn: false,
      columnSpacing: 24,
      headingRowHeight: headerHeight,
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      columns: const [
        DataColumn(columnWidth: FlexColumnWidth(1), label: Text('Legajo')),
        DataColumn(columnWidth: FlexColumnWidth(3), label: Text('Colaborador')),
        DataColumn(
          columnWidth: FlexColumnWidth(2.5),
          label: Text('Área / Equipo'),
        ),
        DataColumn(columnWidth: FlexColumnWidth(1.6), label: Text('Seniority')),
        DataColumn(
          columnWidth: FixedColumnWidth(_progressWidth),
          label: Text('Progreso por categoría'),
        ),
      ],
      rows: [
        for (final employee in employees)
          DataRow(
            onSelectChanged: (_) => context.push(
              '/empleados/${Uri.encodeComponent(employee.employeeId)}',
            ),
            cells: [
              DataCell(
                Text(
                  employee.employeeId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.intermediateText,
                  ),
                ),
              ),
              DataCell(_EmployeeCell(employee)),
              DataCell(_AreaTeamCell(employee)),
              DataCell(SeniorityChip(seniority: employee.seniority)),
              DataCell(
                CategoryHoursProgress(
                  compliance: complianceByEmployeeId[employee.employeeId],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EmployeeCell extends StatelessWidget {
  final Employee employee;

  const _EmployeeCell(this.employee);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: cs.outlineVariant,
          child: Text(
            employee.firstName.isEmpty
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
                '${employee.firstName} ${employee.lastName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                orDash(employee.email),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
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
  final Employee employee;

  const _AreaTeamCell(this.employee);

  @override
  Widget build(BuildContext context) {
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
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
