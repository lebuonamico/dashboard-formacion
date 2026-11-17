import 'package:app_finnegans/core/widgets/card_rows.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/employee_categories_grid.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/employee_header.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/employee_taught_courses.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

final _employee = Employee(
  employeeId: 'EMP-005',
  firstName: 'Valeria',
  lastName: 'Ríos',
  seniority: Seniority.senior1,
  area: 'Desarrollo',
  email: 'valeria.rios@finnegans-demo.com',
  team: 'Frontend Arquitectura & UI',
  manager: 'Valeria Ríos',
);

final _compliance = EmployeeCompliance(
  employee: _employee,
  creditedHours: const {
    CourseCategory.softSkills: 4,
    CourseCategory.exploration: 2,
    CourseCategory.teaching: 4,
  },
  declaredHours: const {
    CourseCategory.softSkills: 4,
    CourseCategory.exploration: 2,
    CourseCategory.teaching: 4,
  },
  requiredHours: const {
    CourseCategory.softSkills: 2,
    CourseCategory.exploration: 2,
    CourseCategory.teaching: 4,
  },
  applicableHours: const {
    CourseCategory.softSkills: 2,
    CourseCategory.exploration: 2,
    CourseCategory.teaching: 4,
  },
  totalCreditedHours: 8,
  totalDeclaredHours: 10,
  totalRequiredHours: 8,
  totalPercentage: 100,
  meetsTarget: true,
);

const _taught = [
  TaughtCourse(
    code: 'CUR-T1',
    name: 'Formación de Instructores',
    area: 'Dictado de capacitaciones',
    hours: 4,
  ),
  TaughtCourse(code: 'CUR-T2', name: 'Liderazgo', area: '', hours: 2),
];

Future<void> _show(WidgetTester tester, Size size, Widget child) => pumpScreen(
  tester,
  size: size,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  ],
);

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

void main() {
  group('Header', () {
    final header = EmployeeHeader(
      employee: _employee,
      compliance: _compliance,
      showCompliance: true,
    );
    final hours = find.byKey(const Key('perfil_horas_validas'));
    final name = find.text('Valeria Ríos').first;

    testWidgets('a 390 px la caja de horas va debajo de los datos', (
      tester,
    ) async {
      await _show(tester, compactSize, header);

      expect(find.text('8 / 8 hs válidas'), findsOneWidget);
      expect(find.text('Frontend Arquitectura & UI'), findsOneWidget);
      // Under the leader, across the panel (390 - 2 × 16 of the screen and
      // 2 × 16 of the panel, less its 1 px border).
      expect(
        _rect(tester, hours).top,
        greaterThan(_rect(tester, find.text('Líder')).bottom),
      );
      expect(_rect(tester, hours).width, 390 - 64 - 2);
    });

    testWidgets('en escritorio la caja sigue al costado', (tester) async {
      await _show(tester, desktopSize, header);

      expect(_rect(tester, hours).left, greaterThan(_rect(tester, name).right));
      expect(_rect(tester, hours).top, lessThan(_rect(tester, name).bottom));
    });

    testWidgets('sin datos del período no muestra la caja', (tester) async {
      await _show(
        tester,
        compactSize,
        EmployeeHeader(
          employee: _employee,
          compliance: _compliance,
          showCompliance: false,
        ),
      );

      expect(hours, findsNothing);
      expect(find.textContaining('Legajo EMP-005'), findsOneWidget);
    });
  });

  group('Categorías', () {
    final grid = EmployeeCategoriesGrid(_compliance);
    Rect card(WidgetTester tester, String label) =>
        _rect(tester, find.text(label));

    testWidgets('a 390 px van de a dos', (tester) async {
      await _show(tester, compactSize, grid);

      expect(find.byType(CardRows), findsOneWidget);
      final business = card(tester, 'Habilidades de negocio');
      final soft = card(tester, 'Habilidades blandas');
      final exploration = card(tester, 'Libres / exploración');
      expect(soft.top, business.top);
      expect(soft.left, greaterThan(business.right));
      expect(exploration.top, greaterThan(business.bottom));
      expect(find.text('No requerida'), findsOneWidget);
      expect(find.text('4 / 4 hs CRM'), findsOneWidget);
    });

    testWidgets('por debajo de 360 px, una por fila', (tester) async {
      await _show(tester, const Size(340, 700), grid);

      final business = card(tester, 'Habilidades de negocio');
      final soft = card(tester, 'Habilidades blandas');
      expect(soft.left, business.left);
      expect(soft.top, greaterThan(business.bottom));
    });

    testWidgets('en escritorio, las cuatro en fila', (tester) async {
      await _show(tester, desktopSize, grid);

      expect(find.byType(CardRows), findsNothing);
      expect(
        card(tester, 'Dictado de capacitaciones').top,
        card(tester, 'Habilidades de negocio').top,
      );
    });
  });

  group('Cursos dictados', () {
    testWidgets('a 390 px son tarjetas, sin tabla', (tester) async {
      await _show(tester, compactSize, const EmployeeTaughtCourses(_taught));

      expect(find.byType(DataTable), findsNothing);
      expect(find.byKey(const ValueKey('dictado_CUR-T1')), findsOneWidget);
      expect(find.text('Formación de Instructores'), findsOneWidget);
      expect(find.text('ID CUR-T1'), findsOneWidget);
      expect(find.text('4 hs'), findsOneWidget);
      // An empty thematic area reads as a dash, as everywhere else.
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('en escritorio sigue la tabla', (tester) async {
      await _show(tester, desktopSize, const EmployeeTaughtCourses(_taught));

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Horas sumadas al plan'), findsOneWidget);
    });

    testWidgets('sin cursos dictados lo avisa', (tester) async {
      await _show(tester, compactSize, const EmployeeTaughtCourses([]));

      expect(
        find.text('No registra cursos dictados como instructor.'),
        findsOneWidget,
      );
    });
  });
}
