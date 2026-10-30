import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/certifications/presentation/certifications_screen.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/core/widgets/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _showCertifications(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(null)),
      employeesProvider.overrideWith(
        (ref) async => [
          Employee(
            employeeId: '10',
            firstName: 'Ana',
            lastName: 'Pérez',
            seniority: Seniority.junior1,
            area: 'Servicios',
            team: 'Soporte',
            email: 'ana@finnegans.com',
          ),
        ],
      ),
      coursesProvider.overrideWith(
        (ref) async => [
          Course(
            id: 'C1',
            name: 'Oratoria',
            category: CourseCategory.softSkills,
            courseArea: '',
            instructorEmployeeId: '',
            workloadHours: 4,
          ),
        ],
      ),
      lmsCertificationsProvider.overrideWith(
        (ref) async => [
          LmsCertification(
            employeeId: '10',
            courseName: 'Oratoria',
            isCompleted: true,
            completedAt: DateTime(2026, 7, 20),
          ),
          // Legajo que no está en la nómina: no tiene perfil.
          LmsCertification(
            employeeId: '99',
            courseName: 'Oratoria',
            isCompleted: true,
            completedAt: DateTime(2026, 7, 10),
          ),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);

  // Cada pantalla monta el SideMenu, como el AppShell: así se ve qué sección
  // queda marcada al abrir el perfil.
  Widget withMenu(Widget screen) => Scaffold(
    body: Row(
      children: [
        const SideMenu(),
        Expanded(child: screen),
      ],
    ),
  );
  final router = GoRouter(
    initialLocation: '/certificaciones',
    routes: [
      GoRoute(
        path: '/certificaciones',
        builder: (context, state) => withMenu(const CertificationsScreen()),
      ),
      GoRoute(
        path: '/empleados/:legajo',
        builder: (context, state) =>
            withMenu(Text('Perfil de ${state.pathParameters['legajo']}')),
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
  return router;
}

/// Si el ítem del menú lateral con esa etiqueta está marcado.
bool _checkedItem(WidgetTester tester, String label) {
  final item = tester.widget(
    find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_MenuItem' &&
          (widget as dynamic).label == label,
    ),
  );
  return (item as dynamic).isSelected as bool;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Click en una certificación abre el perfil del colaborador', (
    tester,
  ) async {
    final router = await _showCertifications(tester);

    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/empleados/10?origen=certificaciones');
    expect(find.text('Perfil de 10'), findsOneWidget);
    // El menú sigue en Certificaciones LMS, no salta a Empleados.
    expect(_checkedItem(tester, 'Certificaciones LMS'), isTrue);
    expect(_checkedItem(tester, 'Empleados'), isFalse);
  });

  testWidgets('Un legajo fuera de la nómina no abre nada', (tester) async {
    final router = await _showCertifications(tester);

    await tester.tap(find.text('Legajo 99'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/certificaciones');
    expect(find.byType(CertificationsScreen), findsOneWidget);
  });
}
