import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/areas/presentation/area_detail_screen.dart';
import 'package:app_finnegans/features/areas/presentation/areas_screen.dart';
import 'package:app_finnegans/features/certifications/presentation/certifications_screen.dart';
import 'package:app_finnegans/features/time_entries/presentation/time_entries_screen.dart';
import 'package:app_finnegans/features/courses/presentation/courses_screen.dart';
import 'package:app_finnegans/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app_finnegans/features/employees/presentation/employees_screen.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/teams/presentation/team_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';

const _year = 2026;
const _month = 6;

final _employee = Employee(
  employeeId: '100',
  firstName: 'Ana',
  lastName: 'Pérez',
  seniority: Seniority.junior1,
  area: 'Tecnología',
  email: 'ana@finnegans.com',
  team: 'Plataforma',
  manager: 'Beto',
  hireDate: DateTime(2020, 1, 1),
);

final _course = Course(
  id: '1',
  name: 'Negociación',
  category: CourseCategory.businessSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 4,
);

CrmTimeEntry _timeEntry(DateTime date) => CrmTimeEntry(
  id: 'tx-${date.month}',
  courseName: _course.name,
  employeeId: _employee.employeeId,
  date: date,
  hours: 2,
  kind: TimeEntryKind.taken,
);

Future<ProviderContainer> _show(
  WidgetTester tester, {
  required String route,
  required Widget Function(GoRouterState state) screen,
  List<Employee>? employees,
  List<Course>? courses,
  List<CrmTimeEntry> timeEntries = const [],
  List<LmsCertification> certifications = const [],
}) async {
  tester.view.physicalSize = const Size(2400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final payroll = InMemoryEmployeesRepository(
    employees: employees ?? [_employee],
  );
  final container = ProviderContainer(
    overrides: [
      employeesProvider.overrideWith((ref) => payroll.getEmployees()),
      employeeHistoryProvider.overrideWith(
        (ref) => payroll.getEmployeeHistory(),
      ),
      coursesProvider.overrideWith((ref) async => courses ?? [_course]),
      crmTimeEntriesProvider.overrideWith((ref) async => timeEntries),
      dashboardTimeEntriesProvider.overrideWith((ref) async => timeEntries),
      lmsCertificationsProvider.overrideWith((ref) async => certifications),
      periodFilterProvider.overrideWith(
        () => PeriodFilterNotifier(
          const PeriodFilter(
            scope: PeriodScope.monthly,
            month: _month,
            year: _year,
          ),
        ),
      ),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: route,
    routes: [
      GoRoute(
        path: route.split('?').first,
        builder: (context, state) => screen(state),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard', () {
    testWidgets('sin registros en el período muestra el aviso y no los KPIs', (
      tester,
    ) async {
      await _show(
        tester,
        route: '/dashboard',
        screen: (_) => const DashboardScreen(),
        timeEntries: [_timeEntry(DateTime(_year, 3, 10))],
      );

      expect(
        find.text('No hay datos cargados para Junio 2026.'),
        findsOneWidget,
      );
      expect(find.text('COLABORADORES'), findsNothing);
    });

    testWidgets('con registros en el período muestra los KPIs', (tester) async {
      await _show(
        tester,
        route: '/dashboard',
        screen: (_) => const DashboardScreen(),
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
      );

      expect(find.textContaining('No hay datos cargados'), findsNothing);
      expect(find.text('COLABORADORES'), findsOneWidget);
      expect(find.text('No se encontraron datos.'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
    });

    testWidgets('usa la misma base que Equipos', (tester) async {
      final container = await _show(
        tester,
        route: '/dashboard',
        screen: (_) => const DashboardScreen(),
        employees: [
          _employee,
          // Ni el inactivo ni el que no tiene fecha de ingreso son elegibles.
          Employee(
            employeeId: '200',
            firstName: 'Baja',
            lastName: 'Inactiva',
            seniority: Seniority.junior1,
            area: 'Tecnología',
            email: 'baja@finnegans.com',
            team: 'Plataforma',
            manager: 'Beto',
            hireDate: DateTime(2020, 1, 1),
            isActive: false,
          ),
          Employee(
            employeeId: '300',
            firstName: 'Sin',
            lastName: 'Ingreso',
            seniority: Seniority.junior1,
            area: 'Tecnología',
            email: 'sin@finnegans.com',
            team: 'Plataforma',
            manager: 'Beto',
          ),
        ],
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
        // Finalizó en marzo: no valida las horas CRM de junio.
        certifications: [
          LmsCertification(
            employeeId: _employee.employeeId,
            courseName: _course.name,
            isCompleted: true,
            completedAt: DateTime(_year, 3, 20),
          ),
        ],
      );

      final complianceList = await container.read(
        dashboardComplianceProvider.future,
      );
      final teamsSummary = await container.read(
        teamsPeriodSummaryProvider.future,
      );
      final dashboardHours = complianceList.fold<double>(
        0,
        (total, item) => total + item.totalCreditedHours,
      );

      expect(complianceList.map((item) => item.employee.employeeId).toSet(), {
        _employee.employeeId,
      });
      expect(teamsSummary.employeeCount, 1);
      expect(dashboardHours, teamsSummary.completedHours);
      expect(dashboardHours, 0);
      // La card de horas muestra solo las válidas para el objetivo.
      final hoursCard = find.ancestor(
        of: find.textContaining('HORAS VÁLIDAS'),
        matching: find.byType(DashboardKpiCard),
      );
      expect(hoursCard, findsOneWidget);
      expect(
        find.descendant(of: hoursCard, matching: find.text('0.0 h')),
        findsOneWidget,
      );
    });
  });

  group('Áreas', () {
    testWidgets('sin registros en el período muestra el aviso del período', (
      tester,
    ) async {
      await _show(tester, route: '/areas', screen: (_) => const AreasScreen());

      expect(
        find.text('No hay datos cargados para Junio 2026.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'una búsqueda sin coincidencias no se confunde con falta de datos',
      (tester) async {
        final container = await _show(
          tester,
          route: '/areas',
          screen: (_) => const AreasScreen(),
          timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
        );
        expect(find.text('Tecnología'), findsOneWidget);

        container
            .read(dataFilterSelectionProvider(DataFilterScope.areas).notifier)
            .select('Área', {'Inexistente'});
        await tester.pumpAndSettle();

        expect(
          find.text('No hay áreas que coincidan con la búsqueda.'),
          findsOneWidget,
        );
        expect(find.textContaining('No hay datos cargados'), findsNothing);
      },
    );

    testWidgets('con registros en el período muestra KPIs y tarjetas', (
      tester,
    ) async {
      await _show(
        tester,
        route: '/areas',
        screen: (_) => const AreasScreen(),
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
      );

      expect(find.text('ÁREAS ACTIVAS'), findsOneWidget);
      expect(find.text('Estado de las áreas'), findsOneWidget);
      expect(find.text('Tecnología'), findsOneWidget);
      expect(find.text('Equipos: Plataforma'), findsOneWidget);
      expect(find.text('Ver área'), findsOneWidget);
    });

    testWidgets('el filtro por estado deja afuera las áreas que no coinciden', (
      tester,
    ) async {
      final container = await _show(
        tester,
        route: '/areas',
        screen: (_) => const AreasScreen(),
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
      );

      // Sin certificación LMS las horas no cuentan: el área queda crítica.
      container
          .read(dataFilterSelectionProvider(DataFilterScope.areas).notifier)
          .select('Estado', {'En objetivo'});
      await tester.pumpAndSettle();

      expect(find.text('Ver área'), findsNothing);
      expect(
        find.text('No hay áreas que coincidan con la búsqueda.'),
        findsOneWidget,
      );
    });
  });

  group('Detalle de área', () {
    testWidgets('sin registros en el período muestra el aviso del período', (
      tester,
    ) async {
      await _show(
        tester,
        route: '/area',
        screen: (_) => const AreaDetailScreen(areaName: 'Tecnología'),
      );

      expect(
        find.text('No hay datos cargados para Junio 2026.'),
        findsOneWidget,
      );
      expect(find.textContaining('No pudimos cargar'), findsNothing);
    });

    testWidgets('con registros muestra KPIs, avance, equipos e integrantes', (
      tester,
    ) async {
      await _show(
        tester,
        route: '/area',
        screen: (_) => const AreaDetailScreen(areaName: 'Tecnología'),
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
      );

      expect(find.text('OBJETIVO DEL PERÍODO'), findsOneWidget);
      expect(find.text('Avance del área'), findsOneWidget);
      expect(find.text('Equipos del área'), findsOneWidget);
      // Una vez en la tarjeta del equipo y otra en la columna Equipo.
      expect(find.text('Plataforma'), findsNWidgets(2));
      expect(find.text('Integrantes (1)'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.textContaining('No pudimos cargar'), findsNothing);
    });
  });

  testWidgets(
    'El detalle de equipo sin datos del período no muestra un error',
    (tester) async {
      await _show(
        tester,
        route: '/equipo',
        screen: (_) =>
            const TeamDetailScreen(area: 'Tecnología', team: 'Plataforma'),
      );

      expect(
        find.text('No hay datos cargados para Junio 2026.'),
        findsOneWidget,
      );
      expect(find.textContaining('No pudimos cargar'), findsNothing);
    },
  );

  testWidgets(
    'El detalle de equipo lista integrantes sin checkbox y la fila es clickeable',
    (tester) async {
      await _show(
        tester,
        route: '/equipo',
        screen: (_) =>
            const TeamDetailScreen(area: 'Tecnología', team: 'Plataforma'),
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
      );

      expect(find.text('Integrantes (1)'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.showCheckboxColumn, isFalse);
      expect(table.rows.first.onSelectChanged, isNotNull);
    },
  );

  group('Empleados', () {
    testWidgets('sin nómina importada lo indica', (tester) async {
      await _show(
        tester,
        route: '/empleados',
        screen: (_) => const EmployeesScreen(),
        employees: const [],
      );

      expect(find.text('No hay empleados cargados.'), findsOneWidget);
    });

    testWidgets('con nómina y un filtro sin coincidencias lo distingue', (
      tester,
    ) async {
      final container = await _show(
        tester,
        route: '/empleados',
        screen: (_) => const EmployeesScreen(),
      );

      container
          .read(dataFilterSelectionProvider(DataFilterScope.employees).notifier)
          .select('Área', {'Inexistente'});
      await tester.pumpAndSettle();

      expect(
        find.text('Ningún empleado coincide con los filtros.'),
        findsOneWidget,
      );
      expect(find.text('No hay empleados cargados.'), findsNothing);
    });

    testWidgets('con muchos empleados pagina el directorio', (tester) async {
      final employees = [
        for (var i = 0; i < 80; i++)
          Employee(
            employeeId: '${1000 + i}',
            firstName: 'Empleado',
            lastName: '$i',
            seniority: Seniority.values[i % Seniority.values.length],
            area: 'Tecnología',
            email: 'empleado$i@finnegans.com',
            team: 'Plataforma',
            manager: 'Beto',
          ),
      ];
      await _show(
        tester,
        route: '/empleados',
        screen: (_) => const EmployeesScreen(),
        employees: employees,
      );

      expect(find.textContaining('de 80 empleados'), findsOneWidget);
      expect(find.textContaining('Página 1 de'), findsOneWidget);

      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Página 2 de'), findsOneWidget);
    });
  });

  group('Cursos', () {
    testWidgets('sin catálogo importado lo indica', (tester) async {
      await _show(
        tester,
        route: '/cursos',
        screen: (_) => const CoursesScreen(),
        courses: const [],
      );

      expect(find.text('No hay cursos cargados.'), findsOneWidget);
    });

    testWidgets('con catálogo y búsqueda sin coincidencias lo distingue', (
      tester,
    ) async {
      final container = await _show(
        tester,
        route: '/cursos',
        screen: (_) => const CoursesScreen(),
      );

      container
          .read(dataFilterSelectionProvider(DataFilterScope.courses).notifier)
          .select('Área', {'Inexistente'});
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontraron cursos con los filtros aplicados.'),
        findsOneWidget,
      );
      expect(find.text('No hay cursos cargados.'), findsNothing);
    });
  });

  group('Carga de horas CRM', () {
    testWidgets('sin reporte importado lo indica', (tester) async {
      await _show(
        tester,
        route: '/cursadas',
        screen: (_) => const TimeEntriesScreen(),
      );

      expect(find.text('No hay horas CRM cargadas.'), findsOneWidget);
    });

    testWidgets('con cargas y búsqueda sin coincidencias lo distingue', (
      tester,
    ) async {
      final container = await _show(
        tester,
        route: '/cursadas',
        screen: (_) => const TimeEntriesScreen(),
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
      );

      container
          .read(
            dataFilterSelectionProvider(DataFilterScope.timeEntries).notifier,
          )
          .select('Persona / Legajo', {'inexistente'});
      await tester.pumpAndSettle();

      expect(
        find.text('Ninguna carga de horas coincide con los filtros.'),
        findsOneWidget,
      );
      expect(find.text('No hay horas CRM cargadas.'), findsNothing);
    });

    testWidgets('con cargas y un área sin coincidencias lo distingue', (
      tester,
    ) async {
      final container = await _show(
        tester,
        route: '/cursadas',
        screen: (_) => const TimeEntriesScreen(),
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
      );

      container
          .read(
            dataFilterSelectionProvider(DataFilterScope.timeEntries).notifier,
          )
          .select('Área', {'Inexistente'});
      await tester.pumpAndSettle();

      expect(
        find.text('Ninguna carga de horas coincide con los filtros.'),
        findsOneWidget,
      );
    });

    testWidgets('filtrar por el área del colaborador encuentra la carga', (
      tester,
    ) async {
      final container = await _show(
        tester,
        route: '/cursadas',
        screen: (_) => const TimeEntriesScreen(),
        timeEntries: [_timeEntry(DateTime(_year, _month, 10))],
      );

      container
          .read(
            dataFilterSelectionProvider(DataFilterScope.timeEntries).notifier,
          )
          .select('Área', {'Tecnología'});
      await tester.pumpAndSettle();

      expect(
        find.text('Ninguna carga de horas coincide con los filtros.'),
        findsNothing,
      );
      expect(find.text('Ana Pérez'), findsWidgets);
    });

    testWidgets('con muchas cargas pagina los registros', (tester) async {
      final timeEntries = [
        for (var i = 0; i < 80; i++)
          CrmTimeEntry(
            id: 'tx-$i',
            courseName: _course.name,
            employeeId: _employee.employeeId,
            date: DateTime(_year, _month, 1 + i % 28),
            hours: 1,
            kind: TimeEntryKind.taken,
          ),
      ];
      await _show(
        tester,
        route: '/cursadas',
        screen: (_) => const TimeEntriesScreen(),
        timeEntries: timeEntries,
      );

      expect(find.textContaining('de 80 registros'), findsOneWidget);
      expect(find.textContaining('Página 1 de'), findsOneWidget);

      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Página 2 de'), findsOneWidget);
    });
  });

  group('Certificaciones', () {
    testWidgets('sin finalizaciones importadas lo indica', (tester) async {
      await _show(
        tester,
        route: '/certificaciones',
        screen: (_) => const CertificationsScreen(),
      );

      expect(find.text('No hay certificaciones LMS cargadas.'), findsOneWidget);
    });

    testWidgets(
      'con finalizaciones y búsqueda sin coincidencias lo distingue',
      (tester) async {
        final container = await _show(
          tester,
          route: '/certificaciones',
          screen: (_) => const CertificationsScreen(),
          certifications: [
            LmsCertification(
              employeeId: _employee.employeeId,
              courseName: _course.name,
              isCompleted: true,
              completedAt: DateTime(_year, _month, 20),
            ),
          ],
        );

        container
            .read(
              dataFilterSelectionProvider(
                DataFilterScope.certifications,
              ).notifier,
            )
            .select('Área', {'Inexistente'});
        await tester.pumpAndSettle();

        expect(
          find.text('Ninguna certificación coincide con los filtros.'),
          findsOneWidget,
        );
        expect(find.text('No hay certificaciones LMS cargadas.'), findsNothing);
      },
    );

    testWidgets('el filtro por estado deja afuera las que no coinciden', (
      tester,
    ) async {
      final container = await _show(
        tester,
        route: '/certificaciones',
        screen: (_) => const CertificationsScreen(),
        certifications: [
          LmsCertification(
            employeeId: _employee.employeeId,
            courseName: _course.name,
            isCompleted: true,
            completedAt: DateTime(_year, _month, 20),
          ),
        ],
      );
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('20/06/2026'), findsOneWidget);

      container
          .read(
            dataFilterSelectionProvider(
              DataFilterScope.certifications,
            ).notifier,
          )
          .select('Estado', {'Pendiente'});
      await tester.pumpAndSettle();

      expect(
        find.text('Ninguna certificación coincide con los filtros.'),
        findsOneWidget,
      );
    });

    testWidgets('avisa cuando el curso o el legajo quedan fuera del cálculo', (
      tester,
    ) async {
      await _show(
        tester,
        route: '/certificaciones',
        screen: (_) => const CertificationsScreen(),
        certifications: [
          LmsCertification(
            employeeId: _employee.employeeId,
            courseName: 'Curso que no está en el catálogo',
            isCompleted: true,
            completedAt: DateTime(_year, _month, 20),
          ),
          LmsCertification(
            employeeId: '999',
            courseName: _course.name,
            isCompleted: false,
          ),
        ],
      );

      expect(find.text('2 fuera del cálculo'), findsOneWidget);
      expect(
        find.byTooltip(
          'El curso no está en el catálogo: esta finalización no acredita horas.',
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip(
          'El legajo no está en la nómina: no suma al cumplimiento de ningún equipo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Fuera de la nómina'), findsOneWidget);
    });
  });
}
