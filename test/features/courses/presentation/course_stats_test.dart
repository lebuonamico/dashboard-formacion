import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/courses/domain/course_stats.dart';

Course _course(
  String name, {
  double timeEntry = 8,
  CourseCategory type = CourseCategory.businessSkills,
}) => Course(
  id: name,
  name: name,
  category: type,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: timeEntry,
);

CrmTimeEntry _timeEntry(
  String id,
  String course,
  String employeeId,
  double hours,
  DateTime date, {
  String? classification,
}) => CrmTimeEntry(
  id: id,
  courseName: course,
  employeeId: employeeId,
  date: date,
  hours: hours,
  kind: TimeEntryKind.taken,
  classification: classification,
);

LmsCertification _completion(
  String course,
  String employeeId,
  DateTime? date, {
  bool completed = true,
}) => LmsCertification(
  employeeId: employeeId,
  courseName: course,
  isCompleted: completed,
  completedAt: date,
);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      coursesProvider.overrideWith(
        (ref) async => [
          _course('Finanzas para no financieros'),
          _course('Oratoria', timeEntry: 4),
          _course('Curso sin alumnos'),
          _course(
            'Dictado interno: SQL',
            timeEntry: 4,
            type: CourseCategory.teaching,
          ),
        ],
      ),
      employeesProvider.overrideWith((ref) async => []),
      crmTimeEntriesProvider.overrideWith(
        (ref) async => [
          // Finanzas: dos personas en julio y una de ellas también en agosto.
          _timeEntry(
            '1',
            'Finanzas para no financieros',
            '10',
            3,
            DateTime(2026, 7, 5),
          ),
          _timeEntry(
            '2',
            'Finanzas para no financieros',
            '10',
            2,
            DateTime(2026, 8, 3),
          ),
          // El nombre del CRM se cruza normalizado, como en el cumplimiento.
          _timeEntry(
            '3',
            ' FINANZAS para no-financieros ',
            '20',
            4,
            DateTime(2026, 7, 9),
          ),
          // En un curso de dictado, quien carga horas es quien lo dicta.
          _timeEntry(
            '4',
            'Dictado interno: SQL',
            '30',
            6,
            DateTime(2026, 7, 9),
            classification: 'Dictado de capacitaciones',
          ),
          _timeEntry('5', 'Oratoria', '20', 1.5, DateTime(2025, 12, 1)),
        ],
      ),
      lmsCertificationsProvider.overrideWith(
        (ref) async => [
          _completion(
            'Finanzas para no financieros',
            '10',
            DateTime(2026, 7, 20),
          ),
          _completion(
            'Finanzas para no financieros',
            '20',
            DateTime(2026, 8, 2),
          ),
          // Una pendiente no cuenta como finalizada.
          _completion(
            'Finanzas para no financieros',
            '40',
            null,
            completed: false,
          ),
          _completion('Oratoria', '20', DateTime(2025, 12, 10)),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<Map<String, CourseStats>> _metrics(ProviderContainer container) async {
  // Los providers base son futuros: se espera a que estén listos.
  await container.read(coursesProvider.future);
  await container.read(employeesProvider.future);
  await container.read(crmTimeEntriesProvider.future);
  await container.read(lmsCertificationsProvider.future);
  final courses = await container.read(courseStatsProvider.future);
  return {for (final vm in courses) vm.course.name: vm};
}

void main() {
  test('Sin período suma todo el histórico de cada curso', () async {
    final metrics = await _metrics(_container());

    final finance = metrics['Finanzas para no financieros']!;
    expect(finance.people, 2);
    expect(finance.crmHours, 9);
    expect(finance.averageHoursPerPerson, 4.5);
    expect(finance.completed, 2);

    final speaking = metrics['Oratoria']!;
    expect(speaking.people, 1);
    expect(speaking.crmHours, 1.5);
    expect(speaking.completed, 1);
  });

  test('Un curso de dictado cuenta a quienes lo dictaron', () async {
    final metrics = await _metrics(_container());

    final teaching = metrics['Dictado interno: SQL']!;
    expect(teaching.people, 1);
    expect(teaching.crmHours, 6);
    expect(teaching.averageHoursPerPerson, 6);
  });

  test('Un curso que nadie tomó no tiene promedio', () async {
    final metrics = await _metrics(_container());

    final empty = metrics['Curso sin alumnos']!;
    expect(empty.people, 0);
    expect(empty.crmHours, 0);
    expect(empty.averageHoursPerPerson, isNull);
    expect(empty.completed, 0);
  });

  test('El año y el mes acotan las métricas, no el catálogo', () async {
    final container = _container();
    container.read(courseStatsPeriodProvider.notifier)
      ..setYear(2026)
      ..setMonth(7);

    final metrics = await _metrics(container);

    // El catálogo sigue completo.
    expect(metrics, hasLength(4));
    final finance = metrics['Finanzas para no financieros']!;
    expect(finance.people, 2);
    expect(finance.crmHours, 7);
    expect(finance.completed, 1);
    expect(metrics['Oratoria']!.people, 0);

    // Sin mes, todo el año.
    container.read(courseStatsPeriodProvider.notifier).setMonth(null);
    final annual = await container.read(courseStatsProvider.future);
    final annualFinance = annual.firstWhere(
      (vm) => vm.course.name == 'Finanzas para no financieros',
    );
    expect(annualFinance.crmHours, 9);
    expect(annualFinance.completed, 2);
  });

  test(
    'Los años del filtro salen de las cargas y las finalizaciones',
    () async {
      final container = _container();

      expect(await container.read(availableCourseYearsProvider.future), [
        2026,
        2025,
      ]);
    },
  );
}
