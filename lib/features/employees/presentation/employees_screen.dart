import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/category_hours_progress.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredEmployees = ref.watch(filteredEmployeesProvider);
    final complianceList = ref.watch(globalComplianceProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Directorio de empleados'),

          // Contenido
          Expanded(
            child: Padding(
              padding: screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _EmployeesFiltersBar(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: filteredEmployees.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => ErrorDataState(
                        title: 'No pudimos cargar los empleados',
                        error: err,
                      ),
                      data: (employees) => FadeIn(
                        child: (() {
                          if (employees.isEmpty) {
                            final hasPayroll =
                                ref
                                    .watch(employeesProvider)
                                    .value
                                    ?.isNotEmpty ??
                                false;
                            return SingleChildScrollView(
                              child: hasPayroll
                                  ? const EmptyDataState(
                                      icon: Icons.search_off_outlined,
                                      title:
                                          'Ningún empleado coincide con los filtros.',
                                      message:
                                          'Probá con otra búsqueda o seniority.',
                                    )
                                  : const EmptyDataState(
                                      icon: Icons.people_outline,
                                      title: 'No hay empleados cargados.',
                                      message:
                                          'Importá la nómina para ver el directorio.',
                                    ),
                            );
                          }
                          return complianceList.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => _PaginatedEmployeesTable(
                              employees: employees,
                              complianceByEmployeeId: const {},
                            ),
                            data: (items) {
                              final byEmployeeId = {
                                for (final item in items)
                                  item.employee.employeeId: item,
                              };
                              return _PaginatedEmployeesTable(
                                employees: employees,
                                complianceByEmployeeId: byEmployeeId,
                              );
                            },
                          );
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

/// Selección múltiple por dimensión, independiente de los indicadores.
class _EmployeesFiltersBar extends ConsumerWidget {
  const _EmployeesFiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilterBar(
    scope: DataFilterScope.employees,
    rows: ref.watch(employeeFilterRowsProvider),
  );
}

/// Tabla del directorio, de a una página por vez y a todo el ancho.
class _PaginatedEmployeesTable extends StatefulWidget {
  final List<Employee> employees;
  final Map<String, EmployeeCompliance> complianceByEmployeeId;

  const _PaginatedEmployeesTable({
    required this.employees,
    required this.complianceByEmployeeId,
  });

  @override
  State<_PaginatedEmployeesTable> createState() =>
      _PaginatedEmployeesTableState();
}

class _PaginatedEmployeesTableState extends State<_PaginatedEmployeesTable> {
  // Filas de dos líneas: nombre + mail, área + equipo y las fichas de
  // progreso en dos renglones.
  static const _rowHeight = 56.0;
  static const _headerHeight = 44.0;
  static const _paginatorHeight = 60.0;
  static const _spacing = 12.0;

  /// Debajo de este ancho las columnas se aprietan demasiado: aparece el
  /// scroll horizontal en lugar de cortar todos los textos. Es mayor que en
  /// el CRM porque la columna de progreso tiene ancho fijo.
  static const _minimumWidth = 1100.0;

  /// Las fichas de [CategoryHoursProgress] miden 256 px fijos; la columna
  /// suma el espacio entre columnas para que no desborden.
  static const _progressWidth = 256.0 + 24.0;

  /// Mínimo razonable si la ventana queda muy baja.
  static const _minimumPerPage = 5;

  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant _PaginatedEmployeesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar el filtro o la búsqueda, volver a la primera página.
    if (oldWidget.employees != widget.employees) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.employees.length;

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
        final visible = widget.employees.sublist(start, end);

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
                resultsLabel: 'empleados',
                icon: Icons.people_outline,
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

  Widget _table(List<Employee> visible) {
    // Encabezados, divisores y márgenes salen del dataTableTheme.
    return DataTable(
      showCheckboxColumn: false,
      columnSpacing: 24,
      headingRowHeight: _headerHeight,
      dataRowMinHeight: _rowHeight,
      dataRowMaxHeight: _rowHeight,
      // Proporciones del ancho: el nombre y el área son lo que más se lee,
      // el legajo es un dato corto.
      columns: const [
        DataColumn(columnWidth: FlexColumnWidth(1), label: Text('Legajo')),
        DataColumn(columnWidth: FlexColumnWidth(3), label: Text('Empleado')),
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
        for (final emp in visible)
          DataRow(
            onSelectChanged: (_) =>
                context.push('/empleados/${emp.employeeId}'),
            cells: [
              DataCell(
                Text(
                  emp.employeeId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.intermediateText,
                  ),
                ),
              ),
              DataCell(_employeeCell(emp)),
              DataCell(_areaTeamCell(emp)),
              DataCell(SeniorityChip(seniority: emp.seniority)),
              DataCell(
                CategoryHoursProgress(
                  compliance: widget.complianceByEmployeeId[emp.employeeId],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _employeeCell(Employee emp) {
    final cs = context.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: cs.outlineVariant,
          child: Text(
            emp.firstName.isEmpty ? '?' : emp.firstName.substring(0, 1),
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
                '${emp.firstName} ${emp.lastName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                _showData(emp.email),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _areaTeamCell(Employee emp) {
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
          style: TextStyle(
            fontSize: 12,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _showData(String value) => value.trim().isEmpty ? '-' : value;
}
