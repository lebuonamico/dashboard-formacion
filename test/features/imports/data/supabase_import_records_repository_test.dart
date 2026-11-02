import 'dart:convert';

import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/imports/data/in_memory_import_records_repository.dart';
import 'package:app_finnegans/features/imports/data/supabase_import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_record.dart';
import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/features/certifications/data/supabase_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/data/supabase_courses_repository.dart';
import 'package:app_finnegans/features/employees/data/supabase_employees_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/time_entries/data/supabase_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mapeo del esquema físico Supabase', () {
    test('Empleados conserva los campos y usa legajo como conflicto', () {
      final mapping = SupabaseEmployeesRepository.mapping;
      final employee = Employee(
        employeeId: '10',
        email: 'ana@example.com',
        firstName: 'Ana',
        lastName: 'Pérez',
        seniority: Seniority.senior1,
        area: 'Producto',
        team: 'Formación',
        manager: 'María',
        hireDate: DateTime(2024, 3),
      );
      final row = <String, dynamic>{
        'legajo': '10',
        'correo': 'ana@example.com',
        'nombre': 'Ana',
        'apellido': 'Pérez',
        'seniority': 'senior1',
        'sector': 'Producto',
        'equipo_general': 'Formación',
        'gerente': 'María',
        'fecha_ingreso': '2024-03-01T00:00:00.000',
        'activo': true,
      };

      expect(mapping.table, 'empleados');
      expect(mapping.onConflict, 'legajo');
      expect(mapping.encode(employee.toJson()), row);
      expect(mapping.decode(row), employee.toJson());
    });

    test('Cursos usa id_curso y excluye campos ajenos al contrato LMS', () {
      final mapping = SupabaseCoursesRepository.mapping;

      expect(mapping.table, 'cursos');
      expect(mapping.onConflict, 'id_curso');
      expect(mapping.columns, {
        'id': 'id_curso',
        'name': 'nombre',
        'category': 'clasificacion',
        'workloadHours': 'carga_horaria',
        'isActive': 'activo',
      });
    });

    test('Horas conserva trazabilidad y usa transaccion_id como conflicto', () {
      final mapping = SupabaseCrmTimeEntriesRepository.mapping;
      final entry = CrmTimeEntry(
        id: 'txn-001',
        employeeId: '10',
        courseId: '107',
        courseName: 'Curso CRM',
        date: DateTime(2025, 1, 15),
        caseRef: 'Choras - 90',
        courseDescription: 'Curso CRM',
        classification: 'Capacitación',
        project: 'Proyecto A',
        projectItem: 'Item B',
        hours: 2.5,
        description: 'Actividad original',
        kind: TimeEntryKind.taken,
      );
      final row = <String, dynamic>{
        'transaccion_id': 'txn-001',
        'legajo': '10',
        'curso_id': '107',
        'fecha': '2025-01-15T00:00:00.000',
        'caso': 'Choras - 90',
        'descripcion_curso': 'Curso CRM',
        'clasificacion': 'Capacitación',
        'proyecto': 'Proyecto A',
        'proyecto_item': 'Item B',
        'horas_totales': 2.5,
        'descripcion': 'Actividad original',
      };

      expect(mapping.table, 'horas_capacitacion');
      expect(mapping.onConflict, 'transaccion_id');
      expect(mapping.encode(entry.toJson()), row);
    });

    test('Finalizaciones usa el conflicto compuesto legajo,curso_id', () {
      final mapping = SupabaseLmsCertificationsRepository.mapping;
      final certification = LmsCertification(
        employeeId: '10',
        courseId: '107',
        courseName: 'Curso LMS',
        isCompleted: true,
        completedAt: DateTime(2025, 1, 15),
      );
      final row = <String, dynamic>{
        'legajo': '10',
        'curso_id': '107',
        'finalizo': true,
        'fecha_finalizacion': '2025-01-15T00:00:00.000',
      };

      expect(mapping.table, 'finalizaciones_cursos');
      expect(mapping.onConflict, 'legajo,curso_id');
      expect(mapping.encode(certification.toJson()), row);
    });
  });

  group('Auditoría Supabase de importaciones', () {
    test('Inserta el payload exacto en public.importaciones', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('', 201, request: request);
        }),
      );
      addTearDown(client.dispose);
      final record = ImportRecord(
        fileType: 'horas_crm',
        fileName: 'horas.xlsx',
        dateTime: DateTime.utc(2026, 10, 3, 14, 30),
        status: ImportStatus.completed,
        processedRecords: 7,
        inserted: 5,
        updated: 2,
      );

      await SupabaseImportRecordsRepository(client).register(record);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/importaciones');
      expect(request.headers['content-profile'], 'public');
      expect(request.url.queryParameters.containsKey('on_conflict'), isFalse);
      expect(jsonDecode(request.body), {
        'tipo_archivo': 'horas_crm',
        'nombre_archivo': 'horas.xlsx',
        'fecha_hora': '2026-10-03T14:30:00.000Z',
        'estado': 'completada',
        'registros_procesados': 7,
        'insertados': 5,
        'actualizados': 2,
        'errores': <String>[],
      });
    });

    test(
      'Conserva estado fallida, errores y conteos desconocidos null',
      () async {
        late http.Request request;
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-test-key',
          httpClient: MockClient((incoming) async {
            request = incoming;
            return http.Response('', 201, request: incoming);
          }),
        );
        addTearDown(client.dispose);

        await SupabaseImportRecordsRepository(client).register(
          ImportRecord(
            fileType: 'finalizaciones_lms',
            fileName: 'finalizaciones.xlsx',
            dateTime: DateTime.utc(2026, 10, 3, 15),
            status: ImportStatus.failed,
            processedRecords: 3,
            errors: const [
              'Fila 2: fecha inválida',
              'Fila 3: curso inexistente',
            ],
          ),
        );

        expect(jsonDecode(request.body), {
          'tipo_archivo': 'finalizaciones_lms',
          'nombre_archivo': 'finalizaciones.xlsx',
          'fecha_hora': '2026-10-03T15:00:00.000Z',
          'estado': 'fallida',
          'registros_procesados': 3,
          'insertados': null,
          'actualizados': null,
          'errores': ['Fila 2: fecha inválida', 'Fila 3: curso inexistente'],
        });
      },
    );

    test('Propaga errores PostgREST al caller', () async {
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"message":"denied","code":"42501"}',
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);

      await expectLater(
        SupabaseImportRecordsRepository(client).register(
          ImportRecord(
            fileType: 'empleados',
            fileName: 'empleados.xlsx',
            dateTime: DateTime.utc(2026, 10, 3),
            status: ImportStatus.completed,
            processedRecords: 1,
          ),
        ),
        throwsA(
          isA<PostgrestException>()
              .having((error) => error.code, 'code', '42501')
              .having((error) => error.message, 'message', 'denied'),
        ),
      );
    });
  });

  test(
    'El provider respeta USE_SUPABASE sin inicializar el singleton',
    () async {
      if (!SupabaseConfig.enabled) {
        final container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWith(
              (ref) =>
                  throw StateError('No debe cargarse el cliente desactivado'),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(importRecordsRepositoryProvider),
          isA<InMemoryImportRecordsRepository>(),
        );
        return;
      }

      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient(
          (request) async => http.Response('', 201, request: request),
        ),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(importRecordsRepositoryProvider),
        isA<SupabaseImportRecordsRepository>(),
      );
    },
  );
}
