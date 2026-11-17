import 'package:app_finnegans/core/widgets/record_card.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/category_hours_progress.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/employees/presentation/employees_screen.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

const _year = 2026;
const _month = 6;

Employee _employee(int index) => Employee(
  employeeId: '${100 + index}',
  firstName: index == 0 ? 'Ana' : 'Colaborador',
  lastName: index == 0 ? 'Pérez' : '$index',
  seniority: Seniority.junior1,
  area: 'Tecnología',
  email: 'persona$index@finnegans.com',
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

Future<GoRouter> _show(
  WidgetTester tester, {
  Size size = compactSize,
  int employees = 1,
}) async {
  final payroll = InMemoryEmployeesRepository(
    employees: [for (var i = 0; i < employees; i++) _employee(i)],
  );
  final (:router, container: _) = await pumpScreen(
    tester,
    initialLocation: '/empleados',
    size: size,
    retryErrors: false,
    overrides: [
      employeesProvider.overrideWith((ref) => payroll.getEmployees()),
      employeeHistoryProvider.overrideWith(
        (ref) => payroll.getEmployeeHistory(),
      ),
      coursesProvider.overrideWith((ref) async => [_course]),
      crmTimeEntriesProvider.overrideWith((ref) async => const []),
      dashboardTimeEntriesProvider.overrideWith((ref) async => const []),
      lmsCertificationsProvider.overrideWith(
        (ref) async => [
          LmsCertification(
            employeeId: '100',
            courseName: _course.name,
            isCompleted: true,
            completedAt: DateTime(_year, _month, 10),
          ),
        ],
      ),
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
    routes: [
      GoRoute(
        path: '/empleados',
        builder: (context, state) => const EmployeesScreen(),
      ),
      GoRoute(
        path: '/empleados/:legajo',
        builder: (context, state) =>
            Scaffold(body: Text('Perfil ${state.pathParameters['legajo']}')),
      ),
    ],
  );
  return router;
}

void main() {
  group('Colaboradores en el teléfono (390 px)', () {
    testWidgets('Muestra tarjetas en lugar de la tabla', (tester) async {
      await _show(tester);

      expect(find.byType(DataTable), findsNothing);
      final card = find.byKey(const ValueKey('employee_card_100'));
      expect(card, findsOneWidget);
      for (final text in ['Ana Pérez', 'Legajo 100', 'Tecnología']) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(of: card, matching: find.byType(SeniorityChip)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(CategoryHoursProgress)),
        findsOneWidget,
      );
      // The filters are a button: they do not fit in a row.
      expect(find.byKey(const Key('filter_sheet_button')), findsOneWidget);
    });

    testWidgets('Tocar una tarjeta abre el perfil', (tester) async {
      final router = await _show(tester);

      await tester.ensureVisible(find.byType(RecordCard));
      await tester.tap(find.byType(RecordCard));
      await tester.pumpAndSettle();

      expect(find.text('Perfil 100'), findsOneWidget);
      expect(router.canPop(), isTrue);
    });

    testWidgets('Con muchos colaboradores pagina de a 10', (tester) async {
      await _show(tester, employees: 25);

      expect(find.byType(RecordCard), findsNWidgets(10));
      expect(find.text('Mostrando 1-10 de 25 colaboradores'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Página siguiente'));
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sin nómina lo indica, sin desbordes a 360×640', (
      tester,
    ) async {
      await _show(tester, size: const Size(360, 640), employees: 0);

      expect(find.text('No hay colaboradores cargados.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('A 360×640 las tarjetas entran sin desbordes', (tester) async {
      await _show(tester, size: const Size(360, 640), employees: 3);

      expect(find.byType(RecordCard), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('En escritorio sigue la tabla', (tester) async {
    await _show(tester, size: desktopSize);

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byType(RecordCard), findsNothing);
  });
}
