import 'package:app_finnegans/core/theme/app_theme.dart';
import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/upsert_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/features/settings/presentation/settings_screen.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audit implements ImportRecordsRepository {
  final records = <ImportRecord>[];
  Future<void> Function(ImportRecord)? onRegister;

  @override
  Future<void> register(ImportRecord record) async {
    records.add(record);
    await onRegister?.call(record);
  }
}

class _FileSelector extends FilePicker {
  final Future<FilePickerResult?> Function() select;
  int calls = 0;

  _FileSelector(this.select);

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) {
    calls++;
    return select();
  }
}

class _Courses extends CoursesRepository
    implements CountedUpsertRepository<Course> {
  final saved = <Course>[];
  int queries = 0;
  int upserts = 0;
  Completer<UpsertResult>? persistence;
  Completer<List<Course>>? pendingQuery;
  Object? persistenceError;

  @override
  Future<List<Course>> getCourses({String? id, String? name}) async {
    queries++;
    if (upserts > 0 && pendingQuery != null) {
      return pendingQuery!.future;
    }
    return List.of(saved);
  }

  @override
  Future<UpsertResult> upsertWithResult(List<Course> items) async {
    upserts++;
    if (persistenceError case final error?) throw error;
    final result =
        await (persistence?.future ??
            Future.value(
              UpsertResult(
                processedRecords: items.length,
                inserted: items.length,
                updated: 0,
              ),
            ));
    for (final item in items) {
      saved.removeWhere((course) => course.id == item.id);
      saved.add(item);
    }
    return result;
  }

  @override
  Future<void> upsert(List<Course> items) async {
    await upsertWithResult(items);
  }

  @override
  Future<void> replaceCourses(List<Course> courses) async {
    fail('El importador debe usar UPSERT.');
  }

  @override
  Future<void> resetToMock() async {
    fail('El importador no debe solicitar mocks.');
  }
}

class _Employees extends EmployeesRepository
    implements CountedUpsertRepository<Employee> {
  int queries = 0;
  int saved = 0;
  final batches = <List<Employee>>[];
  final employeesByEmployeeId = <String, Employee>{};

  @override
  Future<List<Employee>> getEmployees({
    String? employeeId,
    String? team,
    String? sector,
  }) async {
    queries++;
    return employeesByEmployeeId.values.toList();
  }

  @override
  Future<void> replaceEmployees(List<Employee> employees) async {
    fail('El importador debe usar UPSERT.');
  }

  @override
  Future<UpsertResult> upsertWithResult(List<Employee> items) async {
    saved++;
    batches.add(List.of(items));
    final updated = items
        .where((item) => employeesByEmployeeId.containsKey(item.employeeId))
        .length;
    for (final item in items) {
      employeesByEmployeeId[item.employeeId] = item;
    }
    return UpsertResult(
      processedRecords: items.length,
      inserted: items.length - updated,
      updated: updated,
    );
  }

  @override
  Future<void> upsert(List<Employee> items) async {
    await upsertWithResult(items);
  }

  @override
  Future<void> resetToMock() async {
    fail('El importador no debe solicitar mocks.');
  }
}

class _Hours extends CrmTimeEntriesRepository {
  int queries = 0;
  List<CrmTimeEntry> Function()? read;

  @override
  Future<List<CrmTimeEntry>> getTimeEntries({
    String? employeeId,
    String? courseId,
    DateTime? from,
    DateTime? until,
  }) async {
    queries++;
    return read?.call() ?? [];
  }

  @override
  Future<void> replaceTimeEntries(List<CrmTimeEntry> timeEntries) async {
    fail('Un archivo inválido no debe persistir horas.');
  }

  @override
  Future<void> resetToMock() async {
    fail('El importador no debe solicitar mocks.');
  }
}

class _Certifications extends LmsCertificationsRepository {
  int queries = 0;
  List<LmsCertification> Function()? read;

  @override
  Future<List<LmsCertification>> getCertifications({
    String? employeeId,
    String? courseId,
  }) async {
    queries++;
    return read?.call() ?? [];
  }

  @override
  Future<void> replaceCertifications(
    List<LmsCertification> certifications,
  ) async {
    fail('La importación de cursos no debe persistir finalizaciones.');
  }
}

FilePickerResult _csv(String name, String content) {
  final bytes = Uint8List.fromList(utf8.encode(content));
  return FilePickerResult([
    PlatformFile(name: name, size: bytes.length, bytes: bytes),
  ]);
}

const _catalog =
    'idCurso,NombreCurso,Clasificacion,CargaHoraria\r\n'
    '107,Curso de prueba,Habilidades de negocio,4\r\n';

bool _preexistingListTileDiagnostic(FlutterErrorDetails details) {
  final error = details.exception;
  if (error is! FlutterError ||
      error.diagnostics.first.toDescription() !=
          'ListTile background color or ink splashes may be invisible.') {
    return false;
  }
  final properties = details.informationCollector?.call();
  if (properties == null) return false;
  final tiles = properties.whereType<DiagnosticsProperty<ListTile>>();
  if (tiles.length != 1) return false;
  final title = tiles.single.value?.title;
  return title is Text &&
      const {
        'Importar nómina desde Excel / CSV',
        'Usar API de Moodle',
        'Importar cursos desde Excel / CSV',
        'Importar carga de horas desde Excel / CSV',
        'Importar certificaciones LMS desde Excel',
      }.contains(title.data);
}

/// Estructura fija que registra lo que la importación pide crear.
class _Structure implements OrgStructureRepository {
  final OrgStructure structure;
  final _Employees employees;
  final missing = <PayrollGaps>[];
  int? savedOnRegister;

  _Structure(this.structure, this.employees);

  @override
  Future<OrgStructure> getStructure() async => structure;

  @override
  Future<void> registerMissing(PayrollGaps gaps) async {
    savedOnRegister = employees.saved;
    missing.add(gaps);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('La importación no debe llamar a ${invocation.memberName}.');
}

Future<ProviderContainer> _showSettings(
  WidgetTester tester, {
  required _Courses courses,
  required _Audit auditLog,
  _Employees? employees,
  _Hours? hours,
  _Certifications? certifications,
  _Structure? structure,
}) async {
  // Flutter now diagnoses existing decorated cards without a Material surface.
  // Recognize only that known diagnostic; unexpected errors still fail tests.
  // It is no longer required to appear: the Moodle SwitchListTile that always
  // triggered it was removed with the Moodle sync (04cf827).
  final reportError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!_preexistingListTileDiagnostic(details)) {
      reportError?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = reportError);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      coursesRepositoryProvider.overrideWithValue(courses),
      employeesRepositoryProvider.overrideWithValue(employees ?? _Employees()),
      crmTimeEntriesRepositoryProvider.overrideWithValue(hours ?? _Hours()),
      lmsCertificationsRepositoryProvider.overrideWithValue(
        certifications ?? _Certifications(),
      ),
      // Sin estructura explícita no se toca el cliente de Supabase, aunque
      // los tests corran con USE_SUPABASE=true.
      orgStructureRepositoryProvider.overrideWithValue(structure),
      if (structure != null)
        sessionDataProvider.overrideWithValue((
          enabled: true,
          email: 'admin@finnegans.com',
          role: 'admin',
        )),
      importRecordsRepositoryProvider.overrideWithValue(auditLog),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/configuracion',
    routes: [
      GoRoute(
        path: '/configuracion',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/otra',
        builder: (context, state) =>
            const Scaffold(body: Text('Otra pantalla')),
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
          // Ahem has unusually wide glyphs; keep the existing sidebar intact.
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
  return container;
}

OutlinedButton _button(WidgetTester tester, String type) =>
    tester.widget<OutlinedButton>(find.byKey(Key('importar_$type')));

void _verifyLoading(WidgetTester tester, String type, bool active) {
  expect(
    find.byKey(Key('loading_$type')),
    active ? findsOneWidget : findsNothing,
  );
  expect(_button(tester, type).onPressed, active ? isNull : isNotNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Servicio y auditoría de importaciones', () {
    test(
      'Espera persistencia, auditoría y refresh; conserva conteos reales',
      () async {
        final save = Completer<UpsertResult>();
        final audit = Completer<void>();
        final refresh = Completer<void>();
        final steps = <String>[];
        final auditLog = _Audit()
          ..onRegister = (record) {
            steps.add('auditoria');
            return audit.future;
          };
        var term = false;
        final task = ImportAuditService(audit: auditLog)
            .run(
              fileType: 'nomina',
              fileName: 'nomina.csv',
              process: () {
                steps.add('persistencia');
                return save.future;
              },
              refresh: () {
                steps.add('refresh');
                return refresh.future;
              },
            )
            .then((result) {
              term = true;
              return result;
            });

        expect(steps, ['persistencia']);
        expect(auditLog.records, isEmpty);
        const outcome = UpsertResult(
          processedRecords: 80,
          inserted: 12,
          updated: 68,
        );
        save.complete(outcome);
        await Future<void>.delayed(Duration.zero);
        expect(steps, ['persistencia', 'auditoria']);
        expect(term, isFalse);
        final record = auditLog.records.single;
        expect(record.fileType, 'nomina');
        expect(record.fileName, 'nomina.csv');
        expect(record.status, ImportStatus.completed);
        expect(record.processedRecords, 80);
        expect(record.inserted, 12);
        expect(record.updated, 68);
        expect(record.errors, isEmpty);
        expect(record.dateTime.isUtc, isTrue);

        audit.complete();
        await Future<void>.delayed(Duration.zero);
        expect(steps, ['persistencia', 'auditoria', 'refresh']);
        expect(term, isFalse);
        refresh.complete();
        expect(await task, same(outcome));
        expect(term, isTrue);
      },
    );

    test('Un error de parsing se audita como fallida y no refresca', () async {
      final auditLog = _Audit();
      var refreshes = 0;
      const error = FormatException('Fecha inválida: 31/02/2026');

      await expectLater(
        ImportAuditService(audit: auditLog).run(
          fileType: 'nomina',
          fileName: 'invalida.csv',
          process: () async => throw error,
          refresh: () async => refreshes++,
        ),
        throwsA(same(error)),
      );

      expect(refreshes, 0);
      final record = auditLog.records.single;
      expect(record.status, ImportStatus.failed);
      expect(record.fileName, 'invalida.csv');
      expect(record.errors.single, contains('31/02/2026'));
      expect(record.processedRecords, 0);
    });

    test(
      'Un error de UPSERT conserva el error original y no refresca',
      () async {
        final auditLog = _Audit();
        var refreshes = 0;
        final error = StateError('UPSERT rechazado por Supabase');

        await expectLater(
          ImportAuditService(audit: auditLog).run(
            fileType: 'horas_crm',
            fileName: 'horas.xlsx',
            process: () async => throw error,
            refresh: () async => refreshes++,
          ),
          throwsA(same(error)),
        );

        expect(refreshes, 0);
        expect(auditLog.records.single.status, ImportStatus.failed);
        expect(auditLog.records.single.errors.single, contains('UPSERT'));
      },
    );

    test(
      'Si falla auditoría de éxito no refresca y registra la falla',
      () async {
        final auditLog = _Audit()
          ..onRegister = (record) async {
            if (record.status == ImportStatus.completed) {
              throw StateError('Auditoría no disponible');
            }
          };
        var refreshes = 0;

        await expectLater(
          ImportAuditService(audit: auditLog).run(
            fileType: 'cursos_lms',
            fileName: 'cursos.csv',
            process: () async => const UpsertResult(
              processedRecords: 25,
              inserted: 0,
              updated: 25,
            ),
            refresh: () async => refreshes++,
          ),
          throwsA(isA<FormatException>()),
        );

        expect(refreshes, 0);
        expect(auditLog.records.last.status, ImportStatus.failed);
        expect(auditLog.records.last.errors.single, contains('Auditoría'));
      },
    );

    test(
      'Una falla de auditoría no oculta el error de datos original',
      () async {
        final auditLog = _Audit()
          ..onRegister = (record) async => throw StateError('Sin conexión');
        const error = FormatException('Curso no encontrado');

        await expectLater(
          ImportAuditService(audit: auditLog).run(
            fileType: 'finalizaciones',
            fileName: 'lms.xlsx',
            process: () async => throw error,
          ),
          throwsA(same(error)),
        );

        expect(auditLog.records.single.status, ImportStatus.failed);
        expect(auditLog.records.single.errors.single, contains('Curso'));
      },
    );

    test(
      'Un error de refresh conserva una sola auditoría completada',
      () async {
        final auditLog = _Audit();
        var refreshes = 0;

        await expectLater(
          ImportAuditService(audit: auditLog).run(
            fileType: 'cursos_lms',
            fileName: 'cursos.csv',
            process: () async => const UpsertResult(
              processedRecords: 25,
              inserted: 0,
              updated: 25,
            ),
            refresh: () async {
              refreshes++;
              throw StateError('GET de cursos no disponible');
            },
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'mensaje',
              contains('Los datos se guardaron, pero no se pudo actualizar'),
            ),
          ),
        );

        expect(refreshes, 1);
        final record = auditLog.records.single;
        expect(record.status, ImportStatus.completed);
        expect(record.processedRecords, 25);
        expect(record.inserted, 0);
        expect(record.updated, 25);
        expect(record.errors, isEmpty);
      },
    );

    test(
      'El modo sin auditoría mantiene la persistencia y el refresh',
      () async {
        var refreshes = 0;
        final result = await const ImportAuditService().run(
          fileType: 'cursos_lms',
          fileName: 'local.csv',
          process: () async =>
              const UpsertResult(processedRecords: 1, inserted: 1, updated: 0),
          refresh: () async => refreshes++,
        );

        expect(result.inserted, 1);
        expect(result.updated, 0);
        expect(refreshes, 1);
      },
    );
  });

  group('Feedback de las importaciones', () {
    testWidgets('Loading inmediato, bloqueo por sección y cancelación segura', (
      tester,
    ) async {
      final selection = Completer<FilePickerResult?>();
      final selector = _FileSelector(() => selection.future);
      FilePicker.platform = selector;
      final auditLog = _Audit();
      final courses = _Courses();
      await _showSettings(tester, courses: courses, auditLog: auditLog);

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      _verifyLoading(tester, 'cursos', true);
      expect(_button(tester, 'nomina').onPressed, isNotNull);
      expect(_button(tester, 'horas').onPressed, isNotNull);
      expect(_button(tester, 'finalizaciones').onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      expect(selector.calls, 1);
      expect(courses.upserts, 0);

      selection.complete(null);
      await tester.pumpAndSettle();
      _verifyLoading(tester, 'cursos', false);
      expect(auditLog.records, isEmpty);
      expect(courses.upserts, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Loading dura hasta persistencia, auditoría y refresh reales', (
      tester,
    ) async {
      FilePicker.platform = _FileSelector(
        () async => _csv('cursos.csv', _catalog),
      );
      final persistence = Completer<UpsertResult>();
      final audit = Completer<void>();
      final refresh = Completer<List<Course>>();
      final courses = _Courses()..persistence = persistence;
      final auditLog = _Audit()..onRegister = (_) => audit.future;
      final container = await _showSettings(
        tester,
        courses: courses,
        auditLog: auditLog,
      );
      final listens = container.listen(coursesProvider, (_, _) {});
      addTearDown(listens.close);
      await container.read(coursesProvider.future);
      courses.pendingQuery = refresh;

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      _verifyLoading(tester, 'cursos', true);
      expect(courses.upserts, 1);
      expect(auditLog.records, isEmpty);
      expect(courses.queries, 2);
      expect(find.byType(SnackBar), findsNothing);

      persistence.complete(
        const UpsertResult(processedRecords: 1, inserted: 0, updated: 1),
      );
      await tester.pump();
      _verifyLoading(tester, 'cursos', true);
      expect(auditLog.records.single.status, ImportStatus.completed);
      expect(auditLog.records.single.inserted, 0);
      expect(auditLog.records.single.updated, 1);
      expect(courses.queries, 2);
      expect(find.byType(SnackBar), findsNothing);

      audit.complete();
      await tester.pump();
      _verifyLoading(tester, 'cursos', true);
      expect(courses.queries, 3);
      expect(find.byType(SnackBar), findsNothing);

      refresh.complete(List.of(courses.saved));
      await tester.pumpAndSettle();
      _verifyLoading(tester, 'cursos', false);
      expect(
        find.text('Se cargaron 1 cursos desde cursos.csv.'),
        findsOneWidget,
      );
      expect(courses.saved.single.id, '107');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Error de Supabase libera loading, audita y no refresca', (
      tester,
    ) async {
      FilePicker.platform = _FileSelector(
        () async => _csv('cursos.csv', _catalog),
      );
      final persistence = Completer<UpsertResult>();
      final courses = _Courses()..persistence = persistence;
      final audit = Completer<void>();
      final auditLog = _Audit()..onRegister = (_) => audit.future;
      final container = await _showSettings(
        tester,
        courses: courses,
        auditLog: auditLog,
      );
      final listens = container.listen(coursesProvider, (_, _) {});
      addTearDown(listens.close);
      await container.read(coursesProvider.future);

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      _verifyLoading(tester, 'cursos', true);
      persistence.completeError(StateError('Supabase rechazó el UPSERT'));
      await tester.pump();
      _verifyLoading(tester, 'cursos', true);
      expect(auditLog.records.single.status, ImportStatus.failed);
      expect(find.byType(SnackBar), findsNothing);
      audit.complete();
      await tester.pumpAndSettle();

      _verifyLoading(tester, 'cursos', false);
      expect(courses.queries, 2);
      expect(courses.saved, isEmpty);
      expect(auditLog.records.single.status, ImportStatus.failed);
      expect(auditLog.records.single.errors.single, contains('Supabase'));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Se cargaron'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Error de parsing se audita antes de cualquier UPSERT', (
      tester,
    ) async {
      FilePicker.platform = _FileSelector(
        () async => _csv('sin_cursos.csv', 'Columna incorrecta\r\nDato\r\n'),
      );
      final courses = _Courses();
      final auditLog = _Audit();
      await _showSettings(tester, courses: courses, auditLog: auditLog);

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pumpAndSettle();

      _verifyLoading(tester, 'cursos', false);
      expect(courses.upserts, 0);
      expect(courses.queries, 0);
      final record = auditLog.records.single;
      expect(record.status, ImportStatus.failed);
      expect(record.fileName, 'sin_cursos.csv');
      expect(record.errors.single, contains('No se encontraron cursos'));
      expect(find.textContaining('No se encontraron cursos'), findsOneWidget);
      expect(find.textContaining('Se cargaron'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renombrar un curso refresca los nombres de horas y LMS', (
      tester,
    ) async {
      FilePicker.platform = _FileSelector(
        () async => _csv('cursos.csv', _catalog),
      );
      final courses = _Courses()
        ..saved.add(Course.fromJson({'id': '107', 'nombre': 'Curso anterior'}));
      final hours = _Hours()
        ..read = () => [
          CrmTimeEntry(
            id: 'txn-1',
            courseId: '107',
            courseName: courses.saved.single.name,
            employeeId: '10',
            date: DateTime.utc(2026, 10, 1),
            hours: 4,
            kind: TimeEntryKind.taken,
          ),
        ];
      final certifications = _Certifications()
        ..read = () => [
          LmsCertification(
            employeeId: '10',
            courseId: '107',
            courseName: courses.saved.single.name,
            isCompleted: true,
            completedAt: DateTime.utc(2026, 10, 1),
          ),
        ];
      final auditLog = _Audit();
      final container = await _showSettings(
        tester,
        courses: courses,
        auditLog: auditLog,
        hours: hours,
        certifications: certifications,
      );
      final timeEntriesSubscription = container.listen(
        crmTimeEntriesProvider,
        (_, _) {},
      );
      final lmsSubscription = container.listen(
        lmsCertificationsProvider,
        (_, _) {},
      );
      addTearDown(timeEntriesSubscription.close);
      addTearDown(lmsSubscription.close);
      expect(
        (await container.read(crmTimeEntriesProvider.future)).single.courseName,
        'Curso anterior',
      );
      expect(
        (await container.read(
          lmsCertificationsProvider.future,
        )).single.courseName,
        'Curso anterior',
      );
      expect(hours.queries, 1);
      expect(certifications.queries, 1);

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pumpAndSettle();

      _verifyLoading(tester, 'cursos', false);
      expect(hours.queries, greaterThan(1));
      expect(certifications.queries, 2);
      expect(
        (await container.read(crmTimeEntriesProvider.future)).single.courseName,
        'Curso de prueba',
      );
      expect(
        (await container.read(
          lmsCertificationsProvider.future,
        )).single.courseName,
        'Curso de prueba',
      );
      expect(auditLog.records.single.status, ImportStatus.completed);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Abandonar la pantalla no interrumpe auditoría ni refresh', (
      tester,
    ) async {
      FilePicker.platform = _FileSelector(
        () async => _csv('cursos.csv', _catalog),
      );
      final persistence = Completer<UpsertResult>();
      final courses = _Courses()..persistence = persistence;
      final hours = _Hours();
      final certifications = _Certifications();
      final auditLog = _Audit();
      final container = await _showSettings(
        tester,
        courses: courses,
        auditLog: auditLog,
        hours: hours,
        certifications: certifications,
      );
      final coursesSubscription = container.listen(coursesProvider, (_, _) {});
      final timeEntriesSubscription = container.listen(
        crmTimeEntriesProvider,
        (_, _) {},
      );
      final lmsSubscription = container.listen(
        lmsCertificationsProvider,
        (_, _) {},
      );
      addTearDown(coursesSubscription.close);
      addTearDown(timeEntriesSubscription.close);
      addTearDown(lmsSubscription.close);
      await Future.wait([
        container.read(coursesProvider.future),
        container.read(crmTimeEntriesProvider.future),
        container.read(lmsCertificationsProvider.future),
      ]);
      final router = GoRouter.of(tester.element(find.byType(SettingsScreen)));
      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      _verifyLoading(tester, 'cursos', true);
      expect(courses.upserts, 1);

      router.go('/otra');
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Otra pantalla'), findsOneWidget);
      expect(auditLog.records, isEmpty);
      expect(courses.queries, 2);

      persistence.complete(
        const UpsertResult(processedRecords: 1, inserted: 1, updated: 0),
      );
      await tester.pumpAndSettle();

      expect(auditLog.records.single.status, ImportStatus.completed);
      expect(auditLog.records.single.inserted, 1);
      expect(courses.queries, 3);
      expect(hours.queries, greaterThan(1));
      expect(certifications.queries, 2);
      expect(
        (await container.read(coursesProvider.future)).single.name,
        'Curso de prueba',
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Refresh fallido libera loading sin duplicar auditoría ni éxito',
      (tester) async {
        FilePicker.platform = _FileSelector(
          () async => _csv('cursos.csv', _catalog),
        );
        final courses = _Courses();
        final auditLog = _Audit();
        final container = await _showSettings(
          tester,
          courses: courses,
          auditLog: auditLog,
        );
        final listens = container.listen(coursesProvider, (_, _) {});
        addTearDown(listens.close);
        await container.read(coursesProvider.future);
        final refresh = Completer<List<Course>>();
        courses.pendingQuery = refresh;

        await tester.tap(find.byKey(const Key('importar_cursos')));
        await tester.pump();
        _verifyLoading(tester, 'cursos', true);
        expect(courses.saved.single.id, '107');
        expect(auditLog.records.single.status, ImportStatus.completed);
        refresh.completeError(StateError('GET de cursos no disponible'));
        await tester.pumpAndSettle();

        _verifyLoading(tester, 'cursos', false);
        expect(auditLog.records.single.status, ImportStatus.completed);
        expect(auditLog.records.single.inserted, 1);
        expect(find.textContaining('Los datos se guardaron'), findsOneWidget);
        expect(find.textContaining('Se cargaron'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Nómina repetida cuenta filas y escribe una vez por legajo', (
      tester,
    ) async {
      FilePicker.platform = _FileSelector(
        () async => _csv(
          'nomina_repetida.csv',
          'legajo,nombre,apellido,seniority,sector,correo,fechaIngreso\r\n'
              '10,Ana,Pérez,Senior,Producto,ana@example.com,01/10/2026\r\n'
              '10,Ana,Pérez,Senior,Producto,ana@example.com,01/10/2026\r\n',
        ),
      );
      final employees = _Employees();
      final courses = _Courses();
      final auditLog = _Audit();
      await _showSettings(
        tester,
        courses: courses,
        auditLog: auditLog,
        employees: employees,
      );

      await tester.tap(find.byKey(const Key('importar_nomina')));
      await tester.pumpAndSettle();

      _verifyLoading(tester, 'nomina', false);
      expect(employees.saved, 1);
      expect(employees.batches.single.single.employeeId, '10');
      expect(employees.employeesByEmployeeId.keys, ['10']);
      final record = auditLog.records.single;
      expect(record.status, ImportStatus.completed);
      expect(record.processedRecords, 2);
      expect(record.inserted, 1);
      expect(record.updated, 0);
      expect(
        find.text('Se importaron 2 registros desde nomina_repetida.csv.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Nómina crea antes las áreas y equipos nuevos, sin repetir los que ya están',
      (tester) async {
        FilePicker.platform = _FileSelector(
          () async => _csv(
            'nomina_estructura.csv',
            'legajo,nombre,apellido,seniority,sector,equipo,correo,fechaIngreso\r\n'
                '10,Ana,Pérez,Senior,Producto,Web,ana@example.com,01/10/2026\r\n'
                '11,Beto,Gil,Junior 1,PRODUCTO,Legacy,beto@example.com,01/10/2026\r\n'
                '12,Caro,Paz,Junior 2,RRHH,Selección,caro@example.com,01/10/2026\r\n',
          ),
        );
        final employees = _Employees();
        final structure = _Structure(
          OrgStructure(
            areas: [Area(id: '1', name: 'PRODUCTO')],
            teams: [Team(id: '10', areaId: '1', name: 'LEGACY')],
          ),
          employees,
        );
        await _showSettings(
          tester,
          courses: _Courses(),
          auditLog: _Audit(),
          employees: employees,
          structure: structure,
        );

        await tester.tap(find.byKey(const Key('importar_nomina')));
        await tester.pumpAndSettle();

        final missing = structure.missing.single;
        // "Producto" ya existe como PRODUCTO y "Legacy" como LEGACY.
        expect(missing.areas, ['RRHH']);
        expect(missing.teams, [
          (area: 'PRODUCTO', team: 'Web'),
          (area: 'RRHH', team: 'Selección'),
        ]);
        // La estructura se registra antes de escribir la nómina.
        expect(structure.savedOnRegister, 0);
        expect(employees.saved, 1);
        expect(employees.employeesByEmployeeId['10']!.area, 'Producto');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Fecha inválida de nómina se rechaza, audita y no refresca', (
      tester,
    ) async {
      FilePicker.platform = _FileSelector(
        () async => _csv(
          'nomina_invalida.csv',
          'legajo,nombre,apellido,seniority,sector,correo,fechaIngreso\r\n'
              '10,Ana,Pérez,Senior,Producto,ana@example.com,31/02/2026\r\n',
        ),
      );
      final employees = _Employees();
      final courses = _Courses();
      final auditLog = _Audit();
      final container = await _showSettings(
        tester,
        courses: courses,
        auditLog: auditLog,
        employees: employees,
      );
      final listens = container.listen(employeesProvider, (_, _) {});
      addTearDown(listens.close);
      await container.read(employeesProvider.future);

      await tester.tap(find.byKey(const Key('importar_nomina')));
      await tester.pumpAndSettle();

      _verifyLoading(tester, 'nomina', false);
      expect(employees.saved, 0);
      expect(employees.queries, 1);
      expect(courses.upserts, 0);
      final record = auditLog.records.single;
      expect(record.status, ImportStatus.failed);
      expect(record.errors.single, contains('31/02/2026'));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Se importaron'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
