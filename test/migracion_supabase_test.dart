import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/data/supabase/supabase_mapping.dart';
import 'package:app_finnegans/data/supabase/supabase_repositories.dart';
import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/registro_importacion.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/importaciones_repository.dart';
import 'package:app_finnegans/domain/servicios/importacion_service.dart';

Curso course({String id = '107', String nombre = 'Curso LMS'}) => Curso(
  id: id,
  nombre: nombre,
  tipo: TipoCurso.habilidadesDeNegocio,
  areaCurso: 'Solo local',
  instructorLegajo: 'Solo local',
  cargaHorariaHs: 4,
);

SupabaseTableMapping mapping(
  String table,
  List<String> fields,
  List<String> conflicts,
) => SupabaseTableMapping(
  table: table,
  columns: {for (final f in fields) f: 'col_$f'},
  conflictFields: conflicts,
);

final courseMapping = mapping(
  'test_catalog',
  ['id', 'nombre', 'tipo', 'cargaHorariaHs'],
  ['id'],
);
final hoursMapping = mapping(
  'test_hours',
  [
    'id',
    'empleadoLegajo',
    'cursoId',
    'fecha',
    'horasTotales',
    'caso',
    'descripcionCurso',
    'clasificacion',
    'proyecto',
    'proyectoItem',
    'descripcion',
  ],
  ['id'],
);
final completionMapping = mapping(
  'test_completion',
  ['legajo', 'cursoId', 'finalizoCurso', 'fechaFinalizacion'],
  ['legajo', 'cursoId'],
);

class Audit implements ImportacionesRepository {
  final records = <RegistroImportacion>[];
  @override
  Future<void> registrar(RegistroImportacion registro) async {
    records.add(registro);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Course matching trims/cases, rejects ambiguity and never interprets Caso as ID',
    () {
      expect(resolverCurso('  CURSO lms ', [course()]).id, '107');
      expect(
        () => resolverCurso('Choras - 107', [course()]),
        throwsFormatException,
      );
      expect(
        () => resolverCurso('Curso', [course(nombre: 'Curso LMS')]),
        throwsFormatException,
      );
      expect(
        () => resolverCurso('Curso LMS', [course(), course(id: '2')]),
        throwsFormatException,
      );
    },
  );

  test('Historical dates reject missing, invalid and overflow values', () {
    for (final value in [
      '',
      'incorrecto',
      '31/02/2025',
      '2025-02-31',
      '2025-13-01',
      '2025-01-01T25:00:00',
      'Infinity',
      '0',
    ]) {
      expect(
        () => fechaObligatoria(value),
        throwsFormatException,
        reason: value,
      );
    }
    expect(fechaObligatoria('15/09/2025'), DateTime(2025, 9, 15));
    expect(fechaObligatoria('2025-09-15'), DateTime(2025, 9, 15));
    expect(fechaObligatoria('45915'), DateTime(2025, 9, 15));
    expect(
      fechaObligatoria('2025-01-01T00:00:00+03:00'),
      DateTime.utc(2024, 12, 31, 21),
    );
    expect(
      () => CargaDeHorasCRM.fromJson({'fecha': 'invalid'}),
      throwsFormatException,
    );
    expect(
      () => CertificacionMoodle.fromJson({'fechaFinalizacion': '2025-02-31'}),
      throwsFormatException,
    );
  });

  test('Local fallback reads mocks without recursion', () async {
    expect(await LocalEmpleadosRepository().getEmpleados(), isNotEmpty);
    expect(await LocalCursosRepository().getCursos(), isNotEmpty);
    expect(
      await LocalCargaDeHorasCRMRepository().getCargasDeHoras(),
      isNotEmpty,
    );
    expect(
      await LocalCertificacionesMoodleRepository().getCertificaciones(),
      isEmpty,
    );
  });

  test(
    'Local UPSERT preserves old CRM data and updates same transaction',
    () async {
      final repo = LocalCargaDeHorasCRMRepository();
      CargaDeHorasCRM item(String id, int month, double hours) =>
          CargaDeHorasCRM(
            id: id,
            cursoNombre: 'Curso LMS',
            cursoId: '107',
            empleadoLegajo: '10',
            fecha: DateTime(2025, month, 1),
            horasTotales: hours,
            tipo: TipoCargaDeHoras.tomada,
          );
      await repo.replaceCargasDeHoras([item('old', 1, 2)]);
      await repo.upsertCargasDeHoras([item('new', 2, 3)]);
      await repo.upsertCargasDeHoras([item('new', 2, 4)]);
      final all = await repo.getCargasDeHoras();
      expect(all.length, 2);
      expect(all.singleWhere((i) => i.id == 'old').horasTotales, 2);
      expect(all.singleWhere((i) => i.id == 'new').horasTotales, 4);
      expect(
        (await repo.getCargasDeHoras(
          desde: DateTime(2025, 2),
          hasta: DateTime(2025, 3),
        )).length,
        1,
      );
    },
  );

  test(
    'First local imports persist only imported records, retaining mocks as fallback',
    () async {
      final repo = LocalCursosRepository();
      await repo.upsertCursos([course()]);
      expect((await repo.getCursos()).map((c) => c.id), ['107']);
      await repo.resetToMock();
      expect(await repo.getCursos(), isNotEmpty);
    },
  );

  test(
    'Local completions keep one row per employee/course and repeated import is idempotent',
    () async {
      final repo = LocalCertificacionesMoodleRepository();
      final january = CertificacionMoodle(
        legajo: '10',
        cursoNombre: 'Curso LMS',
        finalizoCurso: true,
        fechaFinalizacion: DateTime(2025, 1, 1),
      );
      final february = CertificacionMoodle(
        legajo: '10',
        cursoNombre: 'Curso LMS',
        finalizoCurso: true,
        fechaFinalizacion: DateTime(2025, 2, 1),
      );
      await repo.upsertCertificaciones([january]);
      await repo.upsertCertificaciones([february]);
      await repo.upsertCertificaciones([february]);
      final rows = await repo.getCertificaciones();
      expect(rows.length, 1);
      expect(rows.single.fechaFinalizacion, DateTime(2025, 2, 1));
    },
  );

  test('Remote paging returns records beyond a response page', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final offset = int.parse(request.url.queryParameters['offset']!);
        final count = offset == 0 ? 500 : 1;
        return http.Response(
          jsonEncode(
            List.generate(
              count,
              (i) => courseMapping.encode(course(id: '${offset + i}').toJson()),
            ),
          ),
          200,
          request: request,
        );
      }),
    );
    expect(
      (await SupabaseCursosRepository(
        client,
        courseMapping,
      ).getCursos()).length,
      501,
    );
    expect(requests.length, 2);
    expect(requests.last.url.queryParameters['offset'], '500');
    await client.dispose();
  });

  test('Malformed locally stored historical dates are reported', () async {
    SharedPreferences.setMockInitialValues({
      'formacion_carga_de_horas_crm': '[{"fecha":"invalid"}]',
    });
    await expectLater(
      LocalCargaDeHorasCRMRepository().getCargasDeHoras(),
      throwsFormatException,
    );
  });

  test('Physical mappings are explicit and exclude non-contract fields', () {
    expect(
      () => SupabaseTableMapping(table: '', columns: {}, conflictFields: []),
      throwsArgumentError,
    );
    expect(() => courseMapping.column('areaCurso'), throwsStateError);
    expect(
      courseMapping.encode(course().toJson()).keys,
      unorderedEquals([
        'col_id',
        'col_nombre',
        'col_tipo',
        'col_cargaHorariaHs',
      ]),
    );
  });

  test(
    'Supabase filters are sent to PostgREST and HTTP errors propagate',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final courses = SupabaseCursosRepository(client, courseMapping);
      final hours = SupabaseCargaDeHorasCRMRepository(
        client,
        hoursMapping,
        courses,
      );
      await hours.getCargasDeHoras(
        empleadoLegajo: '10',
        cursoId: '107',
        desde: DateTime(2025, 1),
        hasta: DateTime(2025, 2),
      );
      final params = requests.single.url.queryParametersAll;
      expect(params['col_empleadoLegajo'], ['eq.10']);
      expect(params['col_cursoId'], ['eq.107']);
      expect(
        params['col_fecha'],
        containsAll([
          'gte.2025-01-01T00:00:00.000',
          'lt.2025-02-01T00:00:00.000',
        ]),
      );
      await courses.getCursos(nombre: '  A_100%  ');
      expect(
        requests.last.url.queryParameters['col_nombre'],
        r'ilike.A\_100\%',
      );
      final denied = SupabaseClient(
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
      await expectLater(
        SupabaseCursosRepository(denied, courseMapping).getCursos(),
        throwsA(isA<PostgrestException>()),
      );
      await client.dispose();
      await denied.dispose();
    },
  );

  test(
    'Supabase UPSERT resolves FK by catalog name and retains CRM source fields',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.method == 'GET'
                ? jsonEncode([courseMapping.encode(course().toJson())])
                : '',
            request.method == 'GET' ? 200 : 201,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final courses = SupabaseCursosRepository(client, courseMapping);
      final hours = SupabaseCargaDeHorasCRMRepository(
        client,
        hoursMapping,
        courses,
      );
      await hours.replaceCargasDeHoras([
        CargaDeHorasCRM(
          id: 'txn',
          cursoNombre: ' CURSO LMS ',
          cursoId: 'wrong-source-id',
          empleadoLegajo: '10',
          fecha: DateTime(2025, 1, 1),
          horasTotales: 2,
          tipo: TipoCargaDeHoras.tomada,
          caso: 'Choras - 90',
          clasificacion: 'CRM original',
          descripcionCurso: 'Descripción',
          proyecto: 'P',
          proyectoItem: 'I',
          descripcion: 'D',
        ),
      ]);
      final post = requests.last;
      expect(post.method, 'POST');
      expect(post.url.queryParameters['on_conflict'], 'col_id');
      expect(post.headers['prefer'], contains('resolution=merge-duplicates'));
      final row = (jsonDecode(post.body) as List).single as Map;
      expect(row['col_cursoId'], '107');
      expect(row['col_caso'], 'Choras - 90');
      expect(row['col_clasificacion'], 'CRM original');
      expect(row.keys, isNot(contains('tipo')));
      expect(requests.any((r) => r.method == 'DELETE'), isFalse);
      await courses.upsertCursos([course()]);
      final courseRow = (jsonDecode(requests.last.body) as List).single as Map;
      expect(
        courseRow.keys,
        unorderedEquals([
          'col_id',
          'col_nombre',
          'col_tipo',
          'col_cargaHorariaHs',
        ]),
      );
      await client.dispose();
    },
  );

  test(
    'Remote reads hydrate course names from FK without changing ViewModels',
    () async {
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          final row = request.url.path.endsWith('test_completion')
              ? completionMapping.encode({
                  'legajo': '10',
                  'cursoId': '107',
                  'finalizoCurso': true,
                  'fechaFinalizacion': '2025-01-15',
                })
              : courseMapping.encode(course().toJson());
          return http.Response(
            jsonEncode([row]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = SupabaseCertificacionesMoodleRepository(
        client,
        completionMapping,
        SupabaseCursosRepository(client, courseMapping),
      );
      final result = await repo.getCertificaciones(
        legajo: '10',
        cursoId: '107',
      );
      expect(result.single.cursoNombre, 'Curso LMS');
      expect(result.single.cursoId, '107');
      expect(result.single.fechaFinalizacion, DateTime(2025, 1, 15));
      await client.dispose();
    },
  );

  test(
    'Audit hooks record success/failure without inventing insert/update counts',
    () async {
      final audit = Audit();
      final service = ImportacionService(auditoria: audit);
      await service.persistir(
        tipoArchivo: 'horas_crm',
        nombreArchivo: 'file.xlsx',
        registrosProcesados: 1,
        guardar: () async {},
      );
      expect(audit.records.single.estado, EstadoImportacion.completada);
      expect(audit.records.single.insertados, isNull);
      expect(audit.records.single.actualizados, isNull);
      await expectLater(
        service.persistir(
          tipoArchivo: 'horas_crm',
          nombreArchivo: 'file.xlsx',
          registrosProcesados: 1,
          guardar: () async => throw const FormatException('Invalid data'),
        ),
        throwsFormatException,
      );
      expect(audit.records.last.estado, EstadoImportacion.fallida);
      expect(audit.records.last.errores, isNotEmpty);
    },
  );
}
