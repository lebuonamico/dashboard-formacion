import 'dart:async';

import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/features/certifications/data/in_memory_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/lms_certifications_repository_provider.dart';
import 'package:app_finnegans/features/courses/data/in_memory_courses_repository.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_repository_provider.dart';
import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_repository_providers.dart';
import 'package:app_finnegans/features/imports/data/in_memory_import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_notifier.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_providers.dart';
import 'package:app_finnegans/features/org_structure/data/in_memory_org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_repository_provider.dart';
import 'package:app_finnegans/features/time_entries/data/in_memory_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/crm_time_entries_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/spreadsheet_fixtures.dart';

final _now = DateTime.utc(2026, 10, 31, 12);

final _payroll = csvFile(
  'legajo,nombre,apellido,seniority,sector,correo,fechaIngreso\n'
  '10,Ana,Pérez,Senior,Producto,ana@example.com,01/10/2026\n',
  name: 'nomina.csv',
);

final _catalog = csvFile(
  'idCurso,NombreCurso,Clasificacion,CargaHoraria\n107,Excel,Negocio,4\n',
  name: 'cursos.csv',
);

final _hours = csvFile(
  'ID Transacción,Legajo,Fecha,Curso,Horas Total\n'
  'txn-1,10,15/07/2026, excel ,2\n',
  name: 'horas.csv',
);

void main() {
  late InMemoryImportRecordsRepository audit;
  late InMemoryCrmTimeEntriesRepository timeEntries;
  late ProviderContainer container;

  setUp(() {
    audit = InMemoryImportRecordsRepository();
    timeEntries = InMemoryCrmTimeEntriesRepository(const []);
    final employees = InMemoryEmployeesRepository(
      employees: const [],
      now: () => _now,
    );
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => _now),
        importRecordsRepositoryProvider.overrideWithValue(audit),
        employeesRepositoryProvider.overrideWithValue(employees),
        employeeHistoryRepositoryProvider.overrideWithValue(employees),
        coursesRepositoryProvider.overrideWithValue(
          InMemoryCoursesRepository([
            Course(
              id: '107',
              name: 'Excel',
              category: CourseCategory.businessSkills,
              courseArea: '',
              instructorEmployeeId: '',
              workloadHours: 4,
            ),
          ]),
        ),
        crmTimeEntriesRepositoryProvider.overrideWithValue(timeEntries),
        lmsCertificationsRepositoryProvider.overrideWithValue(
          InMemoryLmsCertificationsRepository(const []),
        ),
        orgStructureRepositoryProvider.overrideWithValue(
          InMemoryOrgStructureRepository(areas: [], teams: []),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  ImportNotifier notifier() => container.read(importProvider.notifier);
  Set<ImportFileType> inProgress() =>
      container.read(importProvider).requireValue.inProgress;
  Future<bool> accept(ImportFile file) async => true;

  test('una nómina confirmada se audita y refresca lo que la usa', () async {
    final confirmed = <String>[];

    final outcome = await notifier().importPayroll(
      pickFile: () async => _payroll,
      confirm: (file) async {
        confirmed.add(file.name);
        return true;
      },
    );

    expect(confirmed, ['nomina.csv']);
    expect(outcome!.fileName, 'nomina.csv');
    expect(outcome.result.processedRecords, 1);
    expect(outcome.result.inserted, 1);
    final record = audit.records.single;
    expect(record.fileType, 'nomina');
    expect(record.status, ImportStatus.completed);
    expect(record.dateTime, _now);
    expect(
      (await container.read(employeesProvider.future)).single.firstName,
      'Ana',
    );
    expect(inProgress(), isEmpty);
  });

  test('las horas resuelven el curso con el catálogo cargado', () async {
    final outcome = await notifier().importTimeEntries(
      pickFile: () async => _hours,
      confirm: accept,
    );

    expect(outcome!.result.processedRecords, 1);
    final entry = (await timeEntries.getTimeEntries()).single;
    expect(entry.courseId, '107');
    expect(entry.courseName, 'Excel');
    expect(audit.records.single.fileType, 'horas_crm');
  });

  test('un error se relanza, se audita y libera el tipo', () async {
    await expectLater(
      notifier().importCourses(
        pickFile: () async => csvFile('Columna incorrecta\nDato\n'),
        confirm: accept,
      ),
      throwsA(isA<FormatException>()),
    );

    expect(audit.records.single.status, ImportStatus.failed);
    expect(audit.records.single.fileType, 'cursos_lms');
    expect(inProgress(), isEmpty);
  });

  test('cancelar el archivo o la confirmación no importa nada', () async {
    expect(
      await notifier().importCourses(
        pickFile: () async => null,
        confirm: (_) => fail('Sin archivo no se confirma.'),
      ),
      isNull,
    );
    expect(
      await notifier().importCourses(
        pickFile: () async => _catalog,
        confirm: (_) async => false,
      ),
      isNull,
    );

    expect(audit.records, isEmpty);
    expect(inProgress(), isEmpty);
  });

  test('el tipo queda en curso desde el pedido, ignora un segundo pedido y '
      'deja correr a los otros tipos', () async {
    final picking = Completer<ImportFile?>();
    final first = notifier().importPayroll(
      pickFile: () => picking.future,
      confirm: accept,
    );
    expect(inProgress(), {ImportFileType.payroll});

    expect(
      await notifier().importPayroll(
        pickFile: () => fail('No se abre otro selector.'),
        confirm: accept,
      ),
      isNull,
    );
    final courses = await notifier().importCourses(
      pickFile: () async => _catalog,
      confirm: accept,
    );
    expect(courses!.result.processedRecords, 1);
    expect(inProgress(), {ImportFileType.payroll});

    picking.complete(_payroll);
    expect((await first)!.result.processedRecords, 1);
    expect(inProgress(), isEmpty);
    expect(audit.records.map((record) => record.fileType), [
      'cursos_lms',
      'nomina',
    ]);
  });
}
