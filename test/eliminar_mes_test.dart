import 'dart:convert';

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/data/supabase/supabase_repositories.dart';
import 'package:app_finnegans/domain/modelos/registro_importacion.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/eliminacion_por_mes_repository.dart';
import 'package:app_finnegans/domain/repositorios/importaciones_repository.dart';
import 'package:app_finnegans/domain/servicios/importacion_service.dart';
import 'package:app_finnegans/presentation/configuracion_screen.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/tema_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _carga(String id, String fecha) => {
  'id': id,
  'cursoNombre': 'Curso de prueba',
  'cursoId': '107',
  'empleadoLegajo': '10',
  'fecha': fecha,
  'horasTotales': 2,
  'tipo': 'tomada',
};

Map<String, dynamic> _certificacion(String legajo, String? fecha) => {
  'legajo': legajo,
  'cursoNombre': 'Curso de prueba',
  'cursoId': '107',
  'finalizoCurso': fecha != null,
  'fechaFinalizacion': fecha,
};

void _sembrarDatosLocales() {
  SharedPreferences.setMockInitialValues({
    'formacion_carga_de_horas_crm': jsonEncode([
      _carga('JUL-1', '2026-07-10'),
      _carga('JUL-2', '2026-07-31'),
      _carga('AGO-1', '2026-08-01'),
    ]),
    'formacion_certificaciones_moodle': jsonEncode([
      _certificacion('10', '2026-07-15'),
      _certificacion('11', '2026-08-20'),
      _certificacion('12', null),
    ]),
  });
}

class _Auditoria implements ImportacionesRepository {
  final registros = <RegistroImportacion>[];

  @override
  Future<void> registrar(RegistroImportacion registro) async {
    registros.add(registro);
  }
}

/// Simula un DELETE filtrado por RLS: PostgREST responde OK sin borrar.
class _HorasSinPermiso extends LocalCargaDeHorasCRMRepository
    implements EliminacionPorMesRepository {
  @override
  Future<int> eliminarMes({required int anio, required int mes}) async => 0;
}

Future<_Auditoria> _mostrarConfiguracion(
  WidgetTester tester, {
  CargaDeHorasCRMRepository? horas,
}) async {
  tester.view.physicalSize = const Size(1800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auditoria = _Auditoria();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Sin Supabase no hay login: la eliminación queda habilitada.
        authControllerProvider.overrideWith((ref) => AuthController(null)),
        temaProvider.overrideWith(() => TemaController(ThemeMode.light)),
        cargaDeHorasCRMRepositoryProvider.overrideWithValue(
          horas ?? LocalCargaDeHorasCRMRepository(),
        ),
        certificacionesMoodleRepositoryProvider.overrideWithValue(
          LocalCertificacionesMoodleRepository(),
        ),
        importacionServiceProvider.overrideWithValue(
          ImportacionService(auditoria: auditoria),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ConfiguracionScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auditoria;
}

void main() {
  test('mesesConRegistros agrupa por mes, ignora fechas nulas y ordena', () {
    final meses = mesesConRegistros([
      DateTime(2026, 7, 10),
      DateTime(2026, 8, 1),
      null,
      DateTime(2026, 7, 31, 23, 59),
      DateTime(2025, 12, 5),
    ]);

    expect(
      [for (final mes in meses) (mes.anio, mes.mes, mes.cantidad)],
      [(2026, 8, 1), (2026, 7, 2), (2025, 12, 1)],
    );
  });

  test('En modo local se borran solo las horas CRM del mes elegido', () async {
    _sembrarDatosLocales();
    final repository = LocalCargaDeHorasCRMRepository();

    expect(await repository.eliminarCargasDelMes(anio: 2026, mes: 7), 2);
    expect((await repository.getCargasDeHoras()).map((carga) => carga.id), [
      'AGO-1',
    ]);
  });

  test(
    'En modo local se borran solo las certificaciones LMS del mes',
    () async {
      _sembrarDatosLocales();
      final repository = LocalCertificacionesMoodleRepository();

      expect(
        await repository.eliminarCertificacionesDelMes(anio: 2026, mes: 7),
        1,
      );
      expect(
        (await repository.getCertificaciones()).map((item) => item.legajo),
        ['11', '12'],
      );
    },
  );

  test(
    'Supabase borra el mes con DELETE y cuenta las filas borradas',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {'transaccion_id': 'A'},
              {'transaccion_id': 'B'},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final mappings = container.read(supabaseMappingsProvider);
      final cursos = SupabaseCursosRepository(client, mappings.cursos);

      final horas = SupabaseCargaDeHorasCRMRepository(
        client,
        mappings.horas,
        cursos,
      );
      // Diciembre verifica que el límite superior pase al año siguiente.
      expect(await horas.eliminarCargasDelMes(anio: 2026, mes: 12), 2);
      final borrado = requests.single;
      expect(borrado.method, 'DELETE');
      expect(borrado.url.path, '/rest/v1/horas_capacitacion');
      expect(
        borrado.url.queryParametersAll['fecha'],
        containsAll([
          'gte.2026-12-01T00:00:00.000',
          'lt.2027-01-01T00:00:00.000',
        ]),
      );
      expect(borrado.url.queryParameters['select'], 'transaccion_id');

      final certificaciones = SupabaseCertificacionesMoodleRepository(
        client,
        mappings.finalizaciones,
        cursos,
      );
      await certificaciones.eliminarCertificacionesDelMes(anio: 2026, mes: 7);
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, '/rest/v1/finalizaciones_cursos');
      expect(
        requests.last.url.queryParametersAll['fecha_finalizacion'],
        containsAll([
          'gte.2026-07-01T00:00:00.000',
          'lt.2026-08-01T00:00:00.000',
        ]),
      );
    },
  );

  test('Sin GRANT DELETE en Supabase se informa un mensaje claro', () async {
    final client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'permission denied for table horas_capacitacion',
            'details': null,
            'hint':
                'Grant the required privileges to the current role with: '
                'GRANT DELETE ON public.horas_capacitacion TO authenticated',
          }),
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    final mappings = container.read(supabaseMappingsProvider);
    final horas = SupabaseCargaDeHorasCRMRepository(
      client,
      mappings.horas,
      SupabaseCursosRepository(client, mappings.cursos),
    );

    await expectLater(
      horas.eliminarCargasDelMes(anio: 2026, mes: 7),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('horas_capacitacion'),
            contains('falta el permiso DELETE'),
          ),
        ),
      ),
    );
  });

  testWidgets('Eliminar mes de horas CRM borra, audita y refresca', (
    tester,
  ) async {
    _sembrarDatosLocales();
    final auditoria = await _mostrarConfiguracion(tester);

    await tester.tap(find.byKey(const Key('eliminar_mes_horas')));
    await tester.pumpAndSettle();
    // Se ofrece primero el mes más reciente con datos.
    expect(find.text('Agosto 2026 · 1 registro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('eliminar_mes_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Julio 2026 · 2 registros').last);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Se van a borrar 2 registros de horas CRM de Julio 2026. '
        'Esta acción no se puede deshacer.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('eliminar_mes_confirmar')));
    await tester.pumpAndSettle();

    expect(
      find.text('Se eliminaron 2 registros de Julio 2026.'),
      findsOneWidget,
    );
    final registro = auditoria.registros.single;
    expect(registro.tipoArchivo, 'horas_crm');
    expect(registro.nombreArchivo, 'Eliminación de Julio 2026');
    expect(registro.estado, EstadoImportacion.completada);
    expect(registro.registrosProcesados, 2);

    // Tras el refresh, Julio ya no aparece entre los meses a eliminar.
    await tester.tap(find.byKey(const Key('eliminar_mes_horas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eliminar_mes_selector')));
    await tester.pumpAndSettle();
    expect(find.text('Julio 2026 · 2 registros'), findsNothing);
    expect(find.text('Agosto 2026 · 1 registro'), findsWidgets);
  });

  testWidgets('Eliminar mes de LMS usa la fecha de finalización', (
    tester,
  ) async {
    _sembrarDatosLocales();
    final auditoria = await _mostrarConfiguracion(tester);

    await tester.tap(find.byKey(const Key('eliminar_mes_finalizaciones')));
    await tester.pumpAndSettle();
    expect(find.text('Agosto 2026 · 1 registro'), findsOneWidget);
    await tester.tap(find.byKey(const Key('eliminar_mes_confirmar')));
    await tester.pumpAndSettle();

    expect(find.text('Se eliminó 1 registro de Agosto 2026.'), findsOneWidget);
    expect(auditoria.registros.single.tipoArchivo, 'finalizaciones');
    expect(
      (await LocalCertificacionesMoodleRepository().getCertificaciones()).map(
        (item) => item.legajo,
      ),
      ['10', '12'],
    );
  });

  testWidgets('Cancelar no borra ni audita', (tester) async {
    _sembrarDatosLocales();
    final auditoria = await _mostrarConfiguracion(tester);

    await tester.tap(find.byKey(const Key('eliminar_mes_horas')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(auditoria.registros, isEmpty);
    expect(
      await LocalCargaDeHorasCRMRepository().getCargasDeHoras(),
      hasLength(3),
    );
  });

  testWidgets(
    'Un borrado bloqueado avisa del permiso y se audita como fallido',
    (tester) async {
      _sembrarDatosLocales();
      final auditoria = await _mostrarConfiguracion(
        tester,
        horas: _HorasSinPermiso(),
      );

      await tester.tap(find.byKey(const Key('eliminar_mes_horas')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eliminar_mes_confirmar')));
      await tester.pumpAndSettle();

      expect(find.textContaining('permiso DELETE (RLS)'), findsOneWidget);
      expect(auditoria.registros.single.estado, EstadoImportacion.fallida);
    },
  );
}
