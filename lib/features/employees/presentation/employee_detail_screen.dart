import 'package:app_finnegans/core/formatting/date_formatter.dart';
import 'package:app_finnegans/core/navigation/app_destination.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/employee_categories_grid.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/employee_courses_columns.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/employee_header.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/employee_projection_section.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/employee_taught_courses.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;

  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(employeeDetailProvider(employeeId));

    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: 'Perfil del colaborador',
            backTo: originBackPath(
              GoRouterState.of(context).uri.queryParameters['origen'],
              '/empleados',
            ),
          ),
          Expanded(
            child: detailAsync.when(
              // Keeps the previous data on screen while the period changes.
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorDataState(
                title: 'No pudimos cargar el colaborador',
                error: err,
                onRetry: () =>
                    ref.invalidate(employeeDetailProvider(employeeId)),
              ),
              data: (detail) => FadeIn(
                child: detail == null
                    ? SingleChildScrollView(
                        child: EmptyDataState(
                          icon: Icons.person_off_outlined,
                          title: 'No encontramos al colaborador $employeeId.',
                          message:
                              'Puede no estar en la nómina o fuera de tu alcance.',
                        ),
                      )
                    : _EmployeeDetailBody(
                        employeeId: employeeId,
                        detail: detail,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeDetailBody extends ConsumerWidget {
  final String employeeId;
  final EmployeeDetail detail;

  const _EmployeeDetailBody({required this.employeeId, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);
    final periodText = period.scope == PeriodScope.annual
        ? 'Año ${period.year}'
        : '${monthName(period.month)} ${period.year}';
    final hasEmployeeData = detail.hasEmployeeData;
    final compliance = detail.compliance;
    final label = periodLabel(period.scope, period.month, period.year);
    final sectionStyle = context.textTheme.bodyLarge!.copyWith(
      fontWeight: FontWeight.w700,
      color: context.colorScheme.onSurface,
    );

    return ListView(
      padding: screenPaddingOf(context),
      children: [
        EmployeeHeader(
          employee: detail.employee,
          compliance: compliance,
          showCompliance: hasEmployeeData,
        ),
        const SizedBox(height: 16),
        const PeriodFilterPanel(
          included:
              'El colaborador cuenta desde su mes de ingreso, aunque tenga 0 '
              'horas.',
        ),
        const SizedBox(height: 24),
        if (!detail.hasPeriodData)
          EmptyDataState.periodWithoutData(period: label)
        else if (!hasEmployeeData)
          _EmployeeWithoutData(employee: detail.employee, period: label)
        else ...[
          Text(
            'Desglose del plan de formación ($periodText)',
            style: sectionStyle,
          ),
          const SizedBox(height: 12),
          EmployeeCategoriesGrid(compliance),
        ],
        const SizedBox(height: 24),
        EmployeeProjectionSection(
          employeeId: employeeId,
          year: period.year,
          titleStyle: sectionStyle,
        ),
        if (hasEmployeeData) ...[
          Text('Cursos del período ($periodText)', style: sectionStyle),
          const SizedBox(height: 12),
          EmployeeCoursesColumns(detail),
          const SizedBox(height: 24),
        ],
        if (hasEmployeeData &&
            ((compliance.requiredHours[CourseCategory.teaching] ?? 0) > 0 ||
                detail.taughtCourses.isNotEmpty)) ...[
          Text('Cursos dictados como instructor', style: sectionStyle),
          const SizedBox(height: 12),
          EmployeeTaughtCourses(detail.taughtCourses),
        ],
      ],
    );
  }
}

/// A period before the employee joined: no data, instead of everything at 0.
class _EmployeeWithoutData extends StatelessWidget {
  final Employee employee;
  final String period;

  const _EmployeeWithoutData({required this.employee, required this.period});

  @override
  Widget build(BuildContext context) {
    final hireDate = employee.hireDate;
    return EmptyDataState(
      icon: Icons.event_busy_outlined,
      title: 'No hay datos cargados del colaborador para $period.',
      message: hireDate == null
          ? null
          : 'Ingresó el ${formatDate(hireDate)}: sus datos se cuentan desde '
                'ese mes.',
    );
  }
}
