import 'dart:async';

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/certifications/domain/certification_record.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/certifications/presentation/certifications_screen.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/core/navigation/app_navigation_drawer.dart';
import 'package:app_finnegans/core/widgets/record_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

/// Ana (legajo 10) finished Oratoria; legajo 99 is not in the payroll.
List<Override> _data({List<LmsCertification> extra = const []}) => [
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
      ...extra,
    ],
  ),
];

Future<GoRouter> _showCertifications(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(2200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [..._data(), ...overrides],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);

  Widget withMenu(Widget screen) => Scaffold(
    body: Row(
      children: [
        const AppNavigationDrawer(),
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
  if (settle) await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return router;
}

const _outsideCatalog =
    'El curso no está en el catálogo: esta finalización no acredita horas.';
const _outsidePayroll =
    'El legajo no está en la nómina: no suma al cumplimiento de ningún equipo.';

/// In a phone window, with a pending course outside the catalog for Ana.
Future<GoRouter> _showCompact(
  WidgetTester tester, {
  Size size = compactSize,
}) async {
  final (:router, container: _) = await pumpScreen(
    tester,
    initialLocation: '/certificaciones',
    size: size,
    retryErrors: false,
    overrides: _data(
      extra: [
        const LmsCertification(
          employeeId: '10',
          courseName: 'Curso fuera del catálogo',
          isCompleted: false,
        ),
      ],
    ),
    routes: [
      GoRoute(
        path: '/certificaciones',
        builder: (context, state) => const CertificationsScreen(),
      ),
      GoRoute(
        path: '/empleados/:legajo',
        builder: (context, state) =>
            Scaffold(body: Text('Perfil de ${state.pathParameters['legajo']}')),
      ),
    ],
  );
  return router;
}

/// Si el ítem del menú lateral con esa etiqueta está marcado.
String? _selectedLabel(WidgetTester tester) {
  final drawer = tester.widget<NavigationDrawer>(find.byType(NavigationDrawer));
  final index = drawer.selectedIndex;
  if (index == null) return null;
  final destination = drawer.children
      .whereType<NavigationDrawerDestination>()
      .elementAt(index);
  return (destination.label as Text).data;
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
    expect(_selectedLabel(tester), 'Certificaciones LMS');
  });

  testWidgets('Un legajo fuera de la nómina no abre nada', (tester) async {
    final router = await _showCertifications(tester);

    await tester.tap(find.text('Legajo 99'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/certificaciones');
    expect(find.byType(CertificationsScreen), findsOneWidget);
  });

  testWidgets('Los KPIs muestran el indicador mientras cargan', (tester) async {
    final kpis = Completer<({CertificationKpis kpis, int payrollCount})>();
    await _showCertifications(
      tester,
      overrides: [
        certificationKpiSummaryProvider.overrideWith((_) => kpis.future),
      ],
      settle: false,
    );
    // La tabla ya cargó; solo los KPIs esperan.
    await tester.pump();
    await tester.pump();

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Colaboradores certificados'), findsNothing);
  });

  testWidgets('Si los KPIs fallan, Reintentar los vuelve a pedir', (
    tester,
  ) async {
    var attempts = 0;
    await _showCertifications(
      tester,
      overrides: [
        certificationKpiSummaryProvider.overrideWith((ref) async {
          attempts++;
          if (attempts == 1) throw Exception('timeout');
          return (
            kpis: await ref.watch(certificationKpisProvider.future),
            payrollCount: 1,
          );
        }),
      ],
    );

    expect(find.text('No pudimos cargar los indicadores'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('No pudimos cargar los indicadores'), findsNothing);
    expect(find.text('de 1 en la nómina'), findsOneWidget);
  });

  group('Certificaciones en el teléfono (390 px)', () {
    testWidgets('Muestra una tarjeta por certificación', (tester) async {
      await _showCompact(tester);

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(RecordCard), findsNWidgets(3));
      final card = find.byKey(const ValueKey('certification_card_10_Oratoria'));
      for (final text in [
        'Ana Pérez',
        'Legajo 10',
        'Finalizado',
        'Oratoria',
        'Servicios',
        'Soporte',
        'Habilidades blandas',
        '4 hs',
        '20/07/2026',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });

    testWidgets('Los avisos se leen como texto, sin hover', (tester) async {
      await _showCompact(tester);

      final outsideCatalog = find.byKey(
        const ValueKey('certification_card_10_Curso fuera del catálogo'),
      );
      expect(
        find.descendant(of: outsideCatalog, matching: find.text('Pendiente')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: outsideCatalog,
          matching: find.text(_outsideCatalog),
        ),
        findsOneWidget,
      );

      final outsidePayroll = find.byKey(
        const ValueKey('certification_card_99_Oratoria'),
      );
      expect(
        find.descendant(
          of: outsidePayroll,
          matching: find.text('Fuera de la nómina'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: outsidePayroll,
          matching: find.text(_outsidePayroll),
        ),
        findsOneWidget,
      );
      expect(find.byType(RecordNotice), findsNWidgets(2));
    });

    testWidgets('Tocar una tarjeta abre el perfil; un legajo de afuera no', (
      tester,
    ) async {
      final router = await _showCompact(tester);

      final outsidePayroll = find.byKey(
        const ValueKey('certification_card_99_Oratoria'),
      );
      await tester.ensureVisible(outsidePayroll);
      await tester.tap(outsidePayroll);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/certificaciones');

      final ana = find.byKey(const ValueKey('certification_card_10_Oratoria'));
      await tester.ensureVisible(ana);
      await tester.tap(ana);
      await tester.pumpAndSettle();
      expect(
        router.state.uri.toString(),
        '/empleados/10?origen=certificaciones',
      );
      expect(find.text('Perfil de 10'), findsOneWidget);
    });

    testWidgets('El botón de notificar va a lo ancho y mide 48 px', (
      tester,
    ) async {
      await _showCompact(tester);

      final button = tester.getSize(
        find.widgetWithText(OutlinedButton, 'Notificar pendientes por mail'),
      );
      expect(button.height, greaterThanOrEqualTo(48));
      // The screen padding is 16 on each side.
      expect(button.width, compactSize.width - 32);
    });

    testWidgets('A 360×640 entra sin desbordes', (tester) async {
      await _showCompact(tester, size: const Size(360, 640));

      expect(find.byType(RecordCard), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });
}
