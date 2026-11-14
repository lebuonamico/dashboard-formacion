import 'package:app_finnegans/core/widgets/info_hint.dart';
import 'package:app_finnegans/core/widgets/record_card.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/presentation/courses_screen.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

Course _course(int index) => Course(
  id: 'CUR-$index',
  name: index == 0 ? 'Negociación con Clientes' : 'Curso $index',
  category: CourseCategory.businessSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 4,
);

CrmTimeEntry _timeEntry(String id, String employeeId, double hours) =>
    CrmTimeEntry(
      id: id,
      courseName: 'Negociación con Clientes',
      employeeId: employeeId,
      date: DateTime(2026, 7, 10),
      hours: hours,
      kind: TimeEntryKind.taken,
    );

Future<void> _show(
  WidgetTester tester, {
  Size size = compactSize,
  int courses = 2,
}) async {
  await pumpScreen(
    tester,
    initialLocation: '/cursos',
    size: size,
    retryErrors: false,
    overrides: [
      coursesProvider.overrideWith(
        (ref) async => [for (var i = 0; i < courses; i++) _course(i)],
      ),
      employeesProvider.overrideWith((ref) async => const []),
      // Two people, 5 hours: 2,5 hs on average.
      crmTimeEntriesProvider.overrideWith(
        (ref) async => [_timeEntry('1', '10', 3), _timeEntry('2', '20', 2)],
      ),
      lmsCertificationsProvider.overrideWith(
        (ref) async => [
          LmsCertification(
            employeeId: '10',
            courseName: 'Negociación con Clientes',
            isCompleted: true,
            completedAt: DateTime(2026, 7, 20),
          ),
        ],
      ),
    ],
    routes: [
      GoRoute(
        path: '/cursos',
        builder: (context, state) => const CoursesScreen(),
      ),
    ],
  );
}

/// The value shown under [label] inside [card].
Finder _metric(Finder card, String label, String value) => find.descendant(
  of: card,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Column &&
        widget.children.length == 2 &&
        widget.children.first is Text &&
        (widget.children.first as Text).data == label &&
        (widget.children.last as Text).data == value,
  ),
);

void main() {
  group('Cursos en el teléfono (390 px)', () {
    testWidgets('Muestra una tarjeta por curso con sus métricas', (
      tester,
    ) async {
      await _show(tester);

      expect(find.byType(DataTable), findsNothing);
      final card = find.byKey(const ValueKey('course_card_CUR-0'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text('Negociación con Clientes'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('ID CUR-0')),
        findsOneWidget,
      );
      for (final (label, value) in [
        ('Carga horaria', '4 hs'),
        ('Colaboradores', '2'),
        ('Horas CRM', '5 hs'),
        ('Promedio por colaborador', '2,5 hs'),
        ('Finalizaron (LMS)', '1'),
      ]) {
        expect(_metric(card, label, value), findsOneWidget, reason: label);
      }
      expect(find.byKey(const Key('filter_sheet_button')), findsOneWidget);
    });

    testWidgets('Un curso que nadie tomó muestra el promedio con raya', (
      tester,
    ) async {
      await _show(tester);

      final card = find.byKey(const ValueKey('course_card_CUR-1'));
      expect(_metric(card, 'Colaboradores', '0'), findsOneWidget);
      expect(_metric(card, 'Promedio por colaborador', '—'), findsOneWidget);
    });

    testWidgets('La ayuda de las métricas se lee con un toque', (tester) async {
      await _show(tester);

      final help = find.byKey(const Key('course_metrics_help'));
      expect(help, findsOneWidget);
      final hint = tester.widget<InfoHint>(
        find.descendant(of: help, matching: find.byType(InfoHint)),
      );
      expect(hint.message, contains('quienes lo dictaron'));
      expect(hint.message, contains('Comparalo con la carga horaria'));
    });

    testWidgets('Con muchos cursos pagina de a 10', (tester) async {
      await _show(tester, courses: 25);

      expect(find.byType(RecordCard), findsNWidgets(10));
      expect(find.text('Mostrando 1-10 de 25 cursos'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Página siguiente'));
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('A 360×640 las tarjetas entran sin desbordes', (tester) async {
      await _show(tester, size: const Size(360, 640), courses: 3);

      expect(find.byType(RecordCard), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('En escritorio sigue la tabla, sin la ayuda de métricas', (
    tester,
  ) async {
    await _show(tester, size: desktopSize);

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byType(RecordCard), findsNothing);
    expect(find.byKey(const Key('course_metrics_help')), findsNothing);
  });
}
