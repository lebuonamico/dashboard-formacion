import 'dart:typed_data';

import 'package:app_finnegans/features/certifications/data/in_memory_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/data/in_memory_courses_repository.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/imports/data/in_memory_import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/imports/domain/import_course_catalog.dart';
import 'package:app_finnegans/features/imports/domain/import_crm_time_entries.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/import_lms_certifications.dart';
import 'package:app_finnegans/features/imports/domain/import_payroll.dart';
import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/domain/payroll_import.dart';
import 'package:app_finnegans/features/imports/domain/snapshot_sync_service.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
import 'package:app_finnegans/features/time_entries/data/in_memory_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:flutter_test/flutter_test.dart';

final _file = ImportFile(name: 'archivo.csv', bytes: Uint8List(0));
final _now = DateTime.utc(2026, 10, 31, 12);

class _Parser<T> implements ImportFileParser<T> {
  final T Function() result;
  int calls = 0;

  _Parser(this.result);

  @override
  T parse(ImportFile file) {
    calls++;
    return result();
  }
}

class _Structure implements OrgStructureRepository {
  final InMemoryEmployeesRepository employees;
  final missing = <PayrollGaps>[];
  List<Employee>? employeesOnRegister;

  _Structure(this.employees);

  @override
  Future<OrgStructure> getStructure() async => const OrgStructure(
    areas: [Area(id: '1', name: 'Producto')],
    teams: [],
  );

  @override
  Future<void> registerMissing(PayrollGaps gaps) async {
    employeesOnRegister = await employees.getEmployees();
    missing.add(gaps);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('La importación no debe llamar a ${invocation.memberName}.');
}

Employee _employee(String id, {String area = 'Producto', String team = ''}) =>
    Employee(
      employeeId: id,
      firstName: 'Nombre $id',
      lastName: 'Apellido',
      seniority: Seniority.senior1,
      area: area,
      email: '$id@example.com',
      team: team,
      hireDate: DateTime(2026),
    );

Course _course(String id, String name) => Course(
  id: id,
  name: name,
  category: CourseCategory.businessSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 4,
);

CrmTimeEntry _entry(String id, String courseName) => CrmTimeEntry(
  id: id,
  courseName: courseName,
  employeeId: '10',
  date: DateTime(2026, 7, 15),
  hours: 2,
  kind: TimeEntryKind.taken,
);

Matcher _rejects(String message) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

void main() {
  late InMemoryImportRecordsRepository audit;
  late ImportAuditService auditService;

  setUp(() {
    audit = InMemoryImportRecordsRepository();
    auditService = ImportAuditService(audit: audit, now: () => _now);
  });

  group('ImportPayroll', () {
    late InMemoryEmployeesRepository employees;
    late _Structure structure;

    ImportPayroll useCase(PayrollImport Function() parsed) => ImportPayroll(
      audit: auditService,
      parser: _Parser(parsed),
      employees: employees,
      orgStructure: structure,
      orgStructureService: const OrgStructureService(),
      snapshotSync: const SnapshotSyncService(),
    );

    setUp(() {
      employees = InMemoryEmployeesRepository(
        employees: [_employee('10'), _employee('99')],
        now: () => _now,
      );
      structure = _Structure(employees);
    });

    test('registra la estructura nueva antes de escribir la nómina', () async {
      await useCase(
        () => PayrollImport(
          employees: [
            _employee('10'),
            _employee('11', area: 'RRHH', team: 'Selección'),
          ],
          rowCount: 2,
        ),
      )(_file);

      expect(structure.missing.single.areas, ['RRHH']);
      expect(structure.missing.single.teams, [
        (area: 'RRHH', team: 'Selección'),
      ]);
      expect(structure.employeesOnRegister!.map((e) => e.employeeId), [
        '10',
        '99',
      ]);
    });

    test('da de baja a los ausentes y cuenta las filas del archivo', () async {
      final result = await useCase(
        () => PayrollImport(
          employees: [_employee('10'), _employee('11')],
          rowCount: 3,
        ),
      )(_file);

      final saved = {
        for (final employee in await employees.getEmployees())
          employee.employeeId: employee.isActive,
      };
      expect(saved, {'10': true, '99': false, '11': true});
      expect(result.processedRecords, 3);
      expect(result.inserted, 1);
      expect(result.updated, 2);
      final record = audit.records.single;
      expect(record.fileType, 'nomina');
      expect(record.fileName, 'archivo.csv');
      expect(record.status, ImportStatus.completed);
      expect(record.processedRecords, 3);
      expect(record.dateTime, _now);
    });

    test('un archivo rechazado se audita y no toca nada', () async {
      await expectLater(
        useCase(() => throw const FormatException('Seniority inválido'))(_file),
        _rejects('Seniority inválido'),
      );

      expect(structure.missing, isEmpty);
      expect(
        (await employees.getEmployees()).every((employee) => employee.isActive),
        isTrue,
      );
      expect(audit.records.single.status, ImportStatus.failed);
      expect(audit.records.single.errors.single, contains('Seniority'));
    });

    test('espera el refresh después de auditar', () async {
      final steps = <String>[];
      await useCase(
        () => PayrollImport(employees: [_employee('10')], rowCount: 1),
      )(
        _file,
        refresh: () async => steps.add('refresh ${audit.records.length}'),
      );

      expect(steps, ['refresh 1']);
    });
  });

  group('ImportCourseCatalog', () {
    test('sincroniza la foto y da de baja los cursos ausentes', () async {
      final courses = InMemoryCoursesRepository([
        _course('1', 'Excel'),
        _course('2', 'Oratoria'),
      ]);

      final result = await ImportCourseCatalog(
        audit: auditService,
        parser: _Parser(() => [_course('1', 'Excel'), _course('3', 'SQL')]),
        courses: courses,
        snapshotSync: const SnapshotSyncService(),
      )(_file);

      final saved = {
        for (final course in await courses.getCourses())
          course.id: course.isActive,
      };
      expect(saved, {'1': true, '2': false, '3': true});
      expect(result.processedRecords, 2);
      expect(audit.records.single.fileType, 'cursos_lms');
      expect(audit.records.single.status, ImportStatus.completed);
    });
  });

  group('ImportCrmTimeEntries', () {
    late InMemoryCrmTimeEntriesRepository timeEntries;
    late int catalogLoads;

    Future<void> import(List<CrmTimeEntry> entries, List<Course> catalog) =>
        ImportCrmTimeEntries(
          audit: auditService,
          parser: _Parser(() => entries),
          timeEntries: timeEntries,
        )(
          _file,
          loadCatalog: () async {
            catalogLoads++;
            return catalog;
          },
        );

    setUp(() {
      timeEntries = InMemoryCrmTimeEntriesRepository(const []);
      catalogLoads = 0;
    });

    test(
      'resuelve cada curso contra el catálogo cargado una sola vez',
      () async {
        await import(
          [
            _entry('txn-1', ' EXCEL '),
            _entry('txn-2', 'excel'),
            _entry('txn-3', 'SQL'),
          ],
          [_course('107', 'Excel'), _course('108', 'SQL')],
        );

        final saved = await timeEntries.getTimeEntries();
        expect(saved.map((e) => (e.id, e.courseId, e.courseName)), [
          ('txn-1', '107', 'Excel'),
          ('txn-2', '107', 'Excel'),
          ('txn-3', '108', 'SQL'),
        ]);
        expect(catalogLoads, 1);
        final record = audit.records.single;
        expect(record.fileType, 'horas_crm');
        expect(record.processedRecords, 3);
        expect(record.inserted, 3);
      },
    );

    test('un curso inexistente corta sin escribir y se audita', () async {
      await expectLater(
        import(
          [_entry('txn-1', 'Excel'), _entry('txn-2', 'Python')],
          [_course('107', 'Excel')],
        ),
        _rejects('Curso inexistente o ambiguo: "Python".'),
      );

      expect(await timeEntries.getTimeEntries(), isEmpty);
      expect(audit.records.single.status, ImportStatus.failed);
    });

    test('un curso ambiguo también corta', () async {
      await expectLater(
        import(
          [_entry('txn-1', 'Excel')],
          [_course('107', 'Excel'), _course('207', 'excel')],
        ),
        _rejects('Curso inexistente o ambiguo: "Excel".'),
      );

      expect(await timeEntries.getTimeEntries(), isEmpty);
    });

    test('si no se puede leer el catálogo, se audita la falla', () async {
      await expectLater(
        ImportCrmTimeEntries(
          audit: auditService,
          parser: _Parser(() => [_entry('txn-1', 'Excel')]),
          timeEntries: timeEntries,
        )(
          _file,
          loadCatalog: () async => throw StateError('Catálogo no disponible'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(audit.records.single.status, ImportStatus.failed);
      expect(audit.records.single.errors.single, contains('Catálogo'));
    });

    test('un archivo rechazado no lee el catálogo', () async {
      await expectLater(
        ImportCrmTimeEntries(
          audit: auditService,
          parser: _Parser(
            () => throw const FormatException('Fila CRM incompleta'),
          ),
          timeEntries: timeEntries,
        )(
          _file,
          loadCatalog: () async {
            catalogLoads++;
            return const [];
          },
        ),
        _rejects('Fila CRM incompleta'),
      );

      expect(catalogLoads, 0);
    });
  });

  group('ImportLmsCertifications', () {
    test('agrega las finalizaciones y cuenta las del archivo', () async {
      final certifications = InMemoryLmsCertificationsRepository(const []);

      final result = await ImportLmsCertifications(
        audit: auditService,
        parser: _Parser(
          () => [
            LmsCertification(
              employeeId: '10',
              courseName: 'Excel',
              isCompleted: true,
              completedAt: DateTime(2026, 7, 15),
            ),
            const LmsCertification(
              employeeId: '11',
              courseName: 'Excel',
              isCompleted: false,
            ),
          ],
        ),
        certifications: certifications,
      )(_file);

      expect(await certifications.getCertifications(), hasLength(2));
      expect(result.processedRecords, 2);
      expect(audit.records.single.fileType, 'finalizaciones');
      expect(audit.records.single.inserted, 2);
    });
  });
}
