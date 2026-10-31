import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/features/certifications/data/in_memory_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/lms_certifications_repository_provider.dart';
import 'package:app_finnegans/features/courses/data/in_memory_courses_repository.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_repository_provider.dart';
import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_repository_providers.dart';
import 'package:app_finnegans/features/imports/data/in_memory_import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_notifier.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_providers.dart';
import 'package:app_finnegans/features/org_structure/data/in_memory_org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_repository_provider.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/time_entries/data/in_memory_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/crm_time_entries_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_import_files.dart';

final _now = DateTime(2026, 10, 31, 12);

/// Someone from an earlier payroll, hired after September, who is absent
/// from the demo payroll.
final _previousEmployee = Employee(
  employeeId: '99',
  firstName: 'Ex',
  lastName: 'Empleado',
  seniority: Seniority.junior1,
  area: 'Producto',
  email: 'ex@finnegans-demo.com',
  team: 'Web',
  hireDate: DateTime(2026, 10, 1),
);

class _Demo {
  final ProviderContainer container;
  final InMemoryEmployeesRepository employees;
  final InMemoryCoursesRepository courses;
  final InMemoryCrmTimeEntriesRepository timeEntries;
  final InMemoryLmsCertificationsRepository certifications;
  final InMemoryImportRecordsRepository audit;

  _Demo._(
    this.container,
    this.employees,
    this.courses,
    this.timeEntries,
    this.certifications,
    this.audit,
  );

  factory _Demo() {
    final employees = InMemoryEmployeesRepository(
      employees: [_previousEmployee],
      now: () => _now,
    );
    final courses = InMemoryCoursesRepository(const []);
    final timeEntries = InMemoryCrmTimeEntriesRepository(const []);
    final certifications = InMemoryLmsCertificationsRepository(const []);
    final audit = InMemoryImportRecordsRepository();
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => _now),
        importRecordsRepositoryProvider.overrideWithValue(audit),
        employeesRepositoryProvider.overrideWithValue(employees),
        employeeHistoryRepositoryProvider.overrideWithValue(employees),
        coursesRepositoryProvider.overrideWithValue(courses),
        crmTimeEntriesRepositoryProvider.overrideWithValue(timeEntries),
        lmsCertificationsRepositoryProvider.overrideWithValue(certifications),
        orgStructureRepositoryProvider.overrideWithValue(
          InMemoryOrgStructureRepository(areas: [], teams: []),
        ),
      ],
      retry: (_, _) => null,
    );
    return _Demo._(
      container,
      employees,
      courses,
      timeEntries,
      certifications,
      audit,
    );
  }

  ImportNotifier get _imports => container.read(importProvider.notifier);

  Future<List<ImportOutcome>> importAll({ImportFile? payroll}) async {
    Future<ImportFile?> Function() pick(ImportFile file) =>
        () async => file;
    Future<bool> accept(ImportFile _) async => true;
    return [
      (await _imports.importCourses(
        pickFile: pick(demoCourses()),
        confirm: accept,
      ))!,
      (await _imports.importPayroll(
        pickFile: pick(payroll ?? demoPayroll()),
        confirm: accept,
      ))!,
      (await _imports.importTimeEntries(
        pickFile: pick(demoTimeEntries()),
        confirm: accept,
      ))!,
      (await _imports.importCertifications(
        pickFile: pick(demoCertifications()),
        confirm: accept,
      ))!,
    ];
  }

  Future<Map<String, TeamStatus>> statusesIn(int month) async {
    container.read(periodFilterProvider.notifier)
      ..setScope(PeriodScope.monthly)
      ..setYear(2026)
      ..setMonth(month);
    final summary = await container.read(teamsPeriodSummaryProvider.future);
    return {for (final team in summary.teams) team.name: team.status};
  }
}

void main() {
  test('los cuatro archivos se importan con los conteos esperados', () async {
    final demo = _Demo();
    addTearDown(demo.container.dispose);

    final outcomes = await demo.importAll();

    expect(outcomes.map((o) => (o.fileName, o.result.processedRecords)), [
      ('cursos_demo.xlsx', 8),
      ('nomina_demo.csv', 6),
      ('horas_crm_demo.csv', 27),
      ('finalizaciones_lms_demo.xlsx', 27),
    ]);
    expect(demo.audit.records.map((r) => (r.fileType, r.status)), [
      ('cursos_lms', ImportStatus.completed),
      ('nomina', ImportStatus.completed),
      ('horas_crm', ImportStatus.completed),
      ('finalizaciones', ImportStatus.completed),
    ]);
  });

  test('cada archivo llega a los repositorios como dice el contrato', () async {
    final demo = _Demo();
    addTearDown(demo.container.dispose);
    await demo.importAll();

    final employees = {
      for (final e in await demo.employees.getEmployees()) e.employeeId: e,
    };
    expect(employees['99']!.isActive, isFalse);
    expect(employees.values.where((e) => e.isActive), hasLength(6));
    expect(employees['10']!.seniority, Seniority.trainee);
    expect(employees['11']!.seniority, Seniority.junior1);
    expect(employees['12']!.seniority, Seniority.junior2);
    expect(employees['12']!.hireDate, DateTime(2025, 5, 15));
    expect(employees['14']!.area, 'Operaciones');
    expect(employees['14']!.team, 'Soporte');
    expect(employees['14']!.email, 'elena@finnegans-demo.com');

    final courses = await demo.courses.getCourses();
    expect(
      courses.map((c) => c.category).toSet(),
      CourseCategory.values.toSet(),
    );
    expect(courses.firstWhere((c) => c.id == 'COM-8').name, 'Comunicación II');

    final entry = (await demo.timeEntries.getTimeEntries()).firstWhere(
      (e) => e.id == 'txn-12-8-2',
    );
    expect(entry.courseId, 'COM-8');
    expect(entry.date, DateTime(2026, 8, 12));
    expect(entry.caseRef, 'Choras - 12');
    expect(entry.project, '01 - Capacitación');
    expect(
      (await demo.timeEntries.getTimeEntries()).any(
        (e) => e.id == 'txn-15-7-2',
      ),
      isFalse,
    );

    final elena = (await demo.certifications.getCertifications()).where(
      (c) => c.employeeId == '14',
    );
    expect(elena.every((c) => !c.isCompleted && c.completedAt == null), isTrue);
  });

  for (final month in demoMonths) {
    test('en $month/2026 hay un equipo en objetivo, uno en riesgo y uno '
        'crítico', () async {
      final demo = _Demo();
      addTearDown(demo.container.dispose);
      await demo.importAll();

      expect(await demo.statusesIn(month), {
        'Web': TeamStatus.onTarget,
        'Mobile': TeamStatus.atRisk,
        'Soporte': TeamStatus.critical,
      });
    });
  }

  test('la nómina con fin de línea CR o CRLF da el mismo resultado', () async {
    Future<List<Map<String, dynamic>>> employeesWith(String eol) async {
      final demo = _Demo();
      addTearDown(demo.container.dispose);
      await demo.importAll(payroll: demoPayroll(eol: eol));
      return [
        for (final employee in await demo.employees.getEmployees())
          employee.toJson(),
      ];
    }

    final lf = await employeesWith('\n');
    expect(await employeesWith('\r'), lf);
    expect(await employeesWith('\r\n'), lf);
  });
}
