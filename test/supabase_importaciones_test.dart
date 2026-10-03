import 'dart:convert';

import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/data/supabase/supabase_importaciones_repository.dart';
import 'package:app_finnegans/domain/modelos/registro_importacion.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mapeo del esquema físico Supabase', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('Empleados conserva los campos y usa legajo como conflicto', () {
      final mapping = container.read(supabaseMappingsProvider).empleados;
      final source = <String, dynamic>{
        'legajo': '10',
        'mail': 'ana@example.com',
        'nombre': 'Ana',
        'apellido': 'Pérez',
        'seniority': 'Senior',
        'area': 'Producto',
        'equipo': 'Formación',
        'gerente': 'María',
        'fechaIngreso': '2024-03-01',
      };
      final row = <String, dynamic>{
        'legajo': '10',
        'correo': 'ana@example.com',
        'nombre': 'Ana',
        'apellido': 'Pérez',
        'seniority': 'Senior',
        'sector': 'Producto',
        'equipo_general': 'Formación',
        'gerente': 'María',
        'fecha_ingreso': '2024-03-01',
      };

      expect(mapping.table, 'empleados');
      expect(mapping.onConflict, 'legajo');
      expect(mapping.encode(source), row);
      expect(mapping.decode(row), source);
    });

    test('Cursos usa id_curso y excluye campos ajenos al contrato LMS', () {
      final mapping = container.read(supabaseMappingsProvider).cursos;
      final source = <String, dynamic>{
        'id': '107',
        'nombre': 'Curso LMS',
        'tipo': 'habilidadesDeNegocio',
        'cargaHorariaHs': 4.0,
      };
      final row = <String, dynamic>{
        'id_curso': '107',
        'nombre': 'Curso LMS',
        'tipo': 'habilidadesDeNegocio',
        'carga_horaria': 4.0,
      };

      expect(mapping.table, 'cursos');
      expect(mapping.onConflict, 'id_curso');
      expect(
        mapping.encode({
          ...source,
          'areaCurso': 'Campo local',
          'instructorLegajo': 'Campo local',
        }),
        row,
      );
      expect(mapping.decode(row), source);
    });

    test('Horas conserva trazabilidad y usa transaccion_id como conflicto', () {
      final mapping = container.read(supabaseMappingsProvider).horas;
      final source = <String, dynamic>{
        'id': 'txn-001',
        'empleadoLegajo': '10',
        'cursoId': '107',
        'fecha': '2025-01-15',
        'caso': 'Choras - 90',
        'descripcionCurso': 'Curso CRM',
        'clasificacion': 'Capacitación',
        'proyecto': 'Proyecto A',
        'proyectoItem': 'Item B',
        'horasTotales': 2.5,
        'descripcion': 'Actividad original',
      };
      final row = <String, dynamic>{
        'transaccion_id': 'txn-001',
        'legajo': '10',
        'curso_id': '107',
        'fecha': '2025-01-15',
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
      expect(mapping.encode(source), row);
      expect(mapping.decode(row), source);
    });

    test('Finalizaciones usa el conflicto compuesto legajo,curso_id', () {
      final mapping = container.read(supabaseMappingsProvider).finalizaciones;
      final source = <String, dynamic>{
        'legajo': '10',
        'cursoId': '107',
        'finalizoCurso': true,
        'fechaFinalizacion': '2025-01-15',
      };
      final row = <String, dynamic>{
        'legajo': '10',
        'curso_id': '107',
        'finalizo': true,
        'fecha_finalizacion': '2025-01-15',
      };

      expect(mapping.table, 'finalizaciones_cursos');
      expect(mapping.onConflict, 'legajo,curso_id');
      expect(mapping.encode(source), row);
      expect(mapping.decode(row), source);
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
      final registro = RegistroImportacion(
        tipoArchivo: 'horas_crm',
        nombreArchivo: 'horas.xlsx',
        fechaHora: DateTime.utc(2026, 10, 3, 14, 30),
        estado: EstadoImportacion.completada,
        registrosProcesados: 7,
        insertados: 5,
        actualizados: 2,
      );

      await SupabaseImportacionesRepository(client).registrar(registro);

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

        await SupabaseImportacionesRepository(client).registrar(
          RegistroImportacion(
            tipoArchivo: 'finalizaciones_lms',
            nombreArchivo: 'finalizaciones.xlsx',
            fechaHora: DateTime.utc(2026, 10, 3, 15),
            estado: EstadoImportacion.fallida,
            registrosProcesados: 3,
            errores: const [
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
        SupabaseImportacionesRepository(client).registrar(
          RegistroImportacion(
            tipoArchivo: 'empleados',
            nombreArchivo: 'empleados.xlsx',
            fechaHora: DateTime.utc(2026, 10, 3),
            estado: EstadoImportacion.completada,
            registrosProcesados: 1,
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

        expect(container.read(importacionesRepositoryProvider), isNull);
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
        container.read(importacionesRepositoryProvider),
        isA<SupabaseImportacionesRepository>(),
      );
    },
  );
}
