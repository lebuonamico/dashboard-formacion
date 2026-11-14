import 'package:app_finnegans/core/widgets/record_card.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/time_entries_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

const _courseName = 'Comunicación Asertiva y Feedback: taller práctico';

CrmTimeEntry _timeEntry(String id, String employeeId) => CrmTimeEntry(
  id: id,
  courseName: _courseName,
  employeeId: employeeId,
  date: DateTime(2026, 7, 10),
  hours: 2,
  kind: TimeEntryKind.taken,
);

Future<GoRouter> _show(
  WidgetTester tester, {
  Size size = compactSize,
  List<CrmTimeEntry>? timeEntries,
}) async {
  final (:router, container: _) = await pumpScreen(
    tester,
    initialLocation: '/cursadas',
    size: size,
    retryErrors: false,
    overrides: [
      employeesProvider.overrideWith(
        (ref) async => [
          Employee(
            employeeId: '100',
            firstName: 'Ana',
            lastName: 'Pérez',
            seniority: Seniority.junior1,
            area: 'Tecnología',
            team: 'Plataforma',
            email: 'ana@finnegans.com',
          ),
        ],
      ),
      coursesProvider.overrideWith(
        (ref) async => [
          Course(
            id: 'CUR-S1',
            name: _courseName,
            category: CourseCategory.softSkills,
            courseArea: '',
            instructorEmployeeId: '',
            workloadHours: 4,
          ),
        ],
      ),
      crmTimeEntriesProvider.overrideWith(
        (ref) async => timeEntries ?? [_timeEntry('TX-1', '100')],
      ),
      lmsCertificationsProvider.overrideWith((ref) async => const []),
    ],
    routes: [
      GoRoute(
        path: '/cursadas',
        builder: (context, state) => const TimeEntriesScreen(),
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
  group('Carga de horas CRM en el teléfono (390 px)', () {
    testWidgets('Muestra una tarjeta por carga', (tester) async {
      await _show(tester);

      expect(find.byType(DataTable), findsNothing);
      final card = find.byKey(const ValueKey('time_entry_card_TX-1'));
      expect(card, findsOneWidget);
      for (final text in [
        'Ana Pérez',
        'Legajo 100',
        '2,00 hs (tomadas)',
        _courseName,
        '10/07/2026',
        'Tecnología',
        'Plataforma',
        'Junior 1',
        'TX-1',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(find.byKey(const Key('filter_sheet_button')), findsOneWidget);
    });

    testWidgets('Tocar una tarjeta abre el perfil desde Carga de horas', (
      tester,
    ) async {
      final router = await _show(tester);

      await tester.tap(find.byType(RecordCard));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), '/empleados/100?origen=cursadas');
      expect(find.text('Perfil 100'), findsOneWidget);
    });

    testWidgets('Un legajo fuera de la nómina lo indica y no abre nada', (
      tester,
    ) async {
      final router = await _show(
        tester,
        timeEntries: [_timeEntry('TX-9', '999')],
      );

      final card = find.byKey(const ValueKey('time_entry_card_TX-9'));
      expect(
        find.descendant(of: card, matching: find.text('Fuera de la nómina')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.chevron_right)),
        findsNothing,
      );

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/cursadas');
    });

    testWidgets('A 360×640 entra sin desbordes', (tester) async {
      await _show(
        tester,
        size: const Size(360, 640),
        timeEntries: [_timeEntry('TX-1', '100'), _timeEntry('TX-2', '999')],
      );

      expect(find.byType(RecordCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('En escritorio sigue la tabla', (tester) async {
    await _show(tester, size: desktopSize);

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byType(RecordCard), findsNothing);
  });
}
