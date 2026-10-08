import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/registro_importacion.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:app_finnegans/domain/repositorios/importaciones_repository.dart';
import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/servicios/importacion_service.dart';
import 'package:app_finnegans/presentation/configuracion_screen.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auditoria implements ImportacionesRepository {
  final registros = <RegistroImportacion>[];
  Future<void> Function(RegistroImportacion)? alRegistrar;

  @override
  Future<void> registrar(RegistroImportacion registro) async {
    registros.add(registro);
    await alRegistrar?.call(registro);
  }
}

class _SelectorArchivo extends FilePicker {
  final Future<FilePickerResult?> Function() seleccionar;
  int llamadas = 0;

  _SelectorArchivo(this.seleccionar);

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
    llamadas++;
    return seleccionar();
  }
}

class _Cursos extends CursosRepository
    implements CountedUpsertRepository<Curso> {
  final guardados = <Curso>[];
  int consultas = 0;
  int upserts = 0;
  Completer<ResultadoUpsert>? persistencia;
  Completer<List<Curso>>? consultaPendiente;
  Object? errorPersistencia;

  @override
  Future<List<Curso>> getCursos({String? id, String? nombre}) async {
    consultas++;
    if (upserts > 0 && consultaPendiente != null) {
      return consultaPendiente!.future;
    }
    return List.of(guardados);
  }

  @override
  Future<ResultadoUpsert> upsertConResultado(List<Curso> items) async {
    upserts++;
    if (errorPersistencia case final error?) throw error;
    final resultado =
        await (persistencia?.future ??
            Future.value(
              ResultadoUpsert(
                registrosProcesados: items.length,
                insertados: items.length,
                actualizados: 0,
              ),
            ));
    for (final item in items) {
      guardados.removeWhere((curso) => curso.id == item.id);
      guardados.add(item);
    }
    return resultado;
  }

  @override
  Future<void> upsert(List<Curso> items) async {
    await upsertConResultado(items);
  }

  @override
  Future<void> replaceCursos(List<Curso> cursos) async {
    fail('El importador debe usar UPSERT.');
  }

  @override
  Future<void> resetToMock() async {
    fail('El importador no debe solicitar mocks.');
  }
}

class _Empleados extends EmpleadosRepository
    implements CountedUpsertRepository<Empleado> {
  int consultas = 0;
  int guardados = 0;
  final lotes = <List<Empleado>>[];
  final empleadosPorLegajo = <String, Empleado>{};

  @override
  Future<List<Empleado>> getEmpleados({
    String? legajo,
    String? equipo,
    String? sector,
  }) async {
    consultas++;
    return empleadosPorLegajo.values.toList();
  }

  @override
  Future<void> replaceEmpleados(List<Empleado> empleados) async {
    fail('El importador debe usar UPSERT.');
  }

  @override
  Future<ResultadoUpsert> upsertConResultado(List<Empleado> items) async {
    guardados++;
    lotes.add(List.of(items));
    final actualizados = items
        .where((item) => empleadosPorLegajo.containsKey(item.legajo))
        .length;
    for (final item in items) {
      empleadosPorLegajo[item.legajo] = item;
    }
    return ResultadoUpsert(
      registrosProcesados: items.length,
      insertados: items.length - actualizados,
      actualizados: actualizados,
    );
  }

  @override
  Future<void> upsert(List<Empleado> items) async {
    await upsertConResultado(items);
  }

  @override
  Future<void> resetToMock() async {
    fail('El importador no debe solicitar mocks.');
  }
}

class _Horas extends CargaDeHorasCRMRepository {
  int consultas = 0;
  List<CargaDeHorasCRM> Function()? leer;

  @override
  Future<List<CargaDeHorasCRM>> getCargasDeHoras({
    String? empleadoLegajo,
    String? cursoId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    consultas++;
    return leer?.call() ?? [];
  }

  @override
  Future<void> replaceCargasDeHoras(List<CargaDeHorasCRM> cargas) async {
    fail('Un archivo inválido no debe persistir horas.');
  }

  @override
  Future<void> resetToMock() async {
    fail('El importador no debe solicitar mocks.');
  }
}

class _Certificaciones extends CertificacionesMoodleRepository {
  int consultas = 0;
  List<CertificacionMoodle> Function()? leer;

  @override
  Future<List<CertificacionMoodle>> getCertificaciones({
    String? legajo,
    String? cursoId,
  }) async {
    consultas++;
    return leer?.call() ?? [];
  }

  @override
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  ) async {
    fail('La importación de cursos no debe persistir finalizaciones.');
  }
}

FilePickerResult _csv(String nombre, String contenido) {
  final bytes = Uint8List.fromList(utf8.encode(contenido));
  return FilePickerResult([
    PlatformFile(name: nombre, size: bytes.length, bytes: bytes),
  ]);
}

const _catalogo =
    'idCurso,NombreCurso,TipoCurso,CargaHoraria\r\n'
    '107,Curso de prueba,Habilidades de negocio,4\r\n';

bool _diagnosticoListTilePreexistente(FlutterErrorDetails details) {
  final error = details.exception;
  if (error is! FlutterError ||
      error.diagnostics.first.toDescription() !=
          'ListTile background color or ink splashes may be invisible.') {
    return false;
  }
  final propiedades = details.informationCollector?.call();
  if (propiedades == null) return false;
  final tiles = propiedades.whereType<DiagnosticsProperty<ListTile>>();
  if (tiles.length != 1) return false;
  final titulo = tiles.single.value?.title;
  return titulo is Text &&
      const {
        'Importar nómina desde Excel / CSV',
        'Usar API de Moodle',
        'Importar cursos desde Excel / CSV',
        'Importar carga de horas desde Excel / CSV',
        'Importar certificaciones LMS desde Excel',
      }.contains(titulo.data);
}

Future<ProviderContainer> _mostrarConfiguracion(
  WidgetTester tester, {
  required _Cursos cursos,
  required _Auditoria auditoria,
  _Empleados? empleados,
  _Horas? horas,
  _Certificaciones? certificaciones,
}) async {
  // Flutter now diagnoses existing decorated cards without a Material surface.
  // Recognize only that known diagnostic; unexpected errors still fail tests.
  final reportarError = FlutterError.onError;
  var diagnosticosConocidos = 0;
  FlutterError.onError = (details) {
    if (_diagnosticoListTilePreexistente(details)) {
      diagnosticosConocidos++;
    } else {
      reportarError?.call(details);
    }
  };
  addTearDown(() {
    FlutterError.onError = reportarError;
    expect(diagnosticosConocidos, greaterThan(0));
  });
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(null)),
      cursosRepositoryProvider.overrideWithValue(cursos),
      empleadosRepositoryProvider.overrideWithValue(empleados ?? _Empleados()),
      cargaDeHorasCRMRepositoryProvider.overrideWithValue(horas ?? _Horas()),
      certificacionesMoodleRepositoryProvider.overrideWithValue(
        certificaciones ?? _Certificaciones(),
      ),
      importacionesRepositoryProvider.overrideWithValue(auditoria),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/configuracion',
    routes: [
      GoRoute(
        path: '/configuracion',
        builder: (context, state) => const ConfiguracionScreen(),
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
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          // Ahem has unusually wide glyphs; keep the existing sidebar intact.
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(0.5)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return container;
}

OutlinedButton _boton(WidgetTester tester, String tipo) =>
    tester.widget<OutlinedButton>(find.byKey(Key('importar_$tipo')));

void _verificarLoading(WidgetTester tester, String tipo, bool activo) {
  expect(
    find.byKey(Key('loading_$tipo')),
    activo ? findsOneWidget : findsNothing,
  );
  expect(_boton(tester, tipo).onPressed, activo ? isNull : isNotNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Servicio y auditoría de importaciones', () {
    test(
      'Espera persistencia, auditoría y refresh; conserva conteos reales',
      () async {
        final guardar = Completer<ResultadoUpsert>();
        final auditar = Completer<void>();
        final refrescar = Completer<void>();
        final pasos = <String>[];
        final auditoria = _Auditoria()
          ..alRegistrar = (registro) {
            pasos.add('auditoria');
            return auditar.future;
          };
        var termino = false;
        final tarea = ImportacionService(auditoria: auditoria)
            .ejecutar(
              tipoArchivo: 'nomina',
              nombreArchivo: 'nomina.csv',
              procesar: () {
                pasos.add('persistencia');
                return guardar.future;
              },
              refrescar: () {
                pasos.add('refresh');
                return refrescar.future;
              },
            )
            .then((resultado) {
              termino = true;
              return resultado;
            });

        expect(pasos, ['persistencia']);
        expect(auditoria.registros, isEmpty);
        const resultado = ResultadoUpsert(
          registrosProcesados: 80,
          insertados: 12,
          actualizados: 68,
        );
        guardar.complete(resultado);
        await Future<void>.delayed(Duration.zero);
        expect(pasos, ['persistencia', 'auditoria']);
        expect(termino, isFalse);
        final registro = auditoria.registros.single;
        expect(registro.tipoArchivo, 'nomina');
        expect(registro.nombreArchivo, 'nomina.csv');
        expect(registro.estado, EstadoImportacion.completada);
        expect(registro.registrosProcesados, 80);
        expect(registro.insertados, 12);
        expect(registro.actualizados, 68);
        expect(registro.errores, isEmpty);
        expect(registro.fechaHora.isUtc, isTrue);

        auditar.complete();
        await Future<void>.delayed(Duration.zero);
        expect(pasos, ['persistencia', 'auditoria', 'refresh']);
        expect(termino, isFalse);
        refrescar.complete();
        expect(await tarea, same(resultado));
        expect(termino, isTrue);
      },
    );

    test('Un error de parsing se audita como fallida y no refresca', () async {
      final auditoria = _Auditoria();
      var refrescos = 0;
      const error = FormatException('Fecha inválida: 31/02/2026');

      await expectLater(
        ImportacionService(auditoria: auditoria).ejecutar(
          tipoArchivo: 'nomina',
          nombreArchivo: 'invalida.csv',
          procesar: () async => throw error,
          refrescar: () async => refrescos++,
        ),
        throwsA(same(error)),
      );

      expect(refrescos, 0);
      final registro = auditoria.registros.single;
      expect(registro.estado, EstadoImportacion.fallida);
      expect(registro.nombreArchivo, 'invalida.csv');
      expect(registro.errores.single, contains('31/02/2026'));
      expect(registro.registrosProcesados, 0);
    });

    test(
      'Un error de UPSERT conserva el error original y no refresca',
      () async {
        final auditoria = _Auditoria();
        var refrescos = 0;
        final error = StateError('UPSERT rechazado por Supabase');

        await expectLater(
          ImportacionService(auditoria: auditoria).ejecutar(
            tipoArchivo: 'horas_crm',
            nombreArchivo: 'horas.xlsx',
            procesar: () async => throw error,
            refrescar: () async => refrescos++,
          ),
          throwsA(same(error)),
        );

        expect(refrescos, 0);
        expect(auditoria.registros.single.estado, EstadoImportacion.fallida);
        expect(auditoria.registros.single.errores.single, contains('UPSERT'));
      },
    );

    test(
      'Si falla auditoría de éxito no refresca y registra la falla',
      () async {
        final auditoria = _Auditoria()
          ..alRegistrar = (registro) async {
            if (registro.estado == EstadoImportacion.completada) {
              throw StateError('Auditoría no disponible');
            }
          };
        var refrescos = 0;

        await expectLater(
          ImportacionService(auditoria: auditoria).ejecutar(
            tipoArchivo: 'cursos_lms',
            nombreArchivo: 'cursos.csv',
            procesar: () async => const ResultadoUpsert(
              registrosProcesados: 25,
              insertados: 0,
              actualizados: 25,
            ),
            refrescar: () async => refrescos++,
          ),
          throwsA(isA<FormatException>()),
        );

        expect(refrescos, 0);
        expect(auditoria.registros.last.estado, EstadoImportacion.fallida);
        expect(auditoria.registros.last.errores.single, contains('Auditoría'));
      },
    );

    test(
      'Una falla de auditoría no oculta el error de datos original',
      () async {
        final auditoria = _Auditoria()
          ..alRegistrar = (registro) async => throw StateError('Sin conexión');
        const error = FormatException('Curso no encontrado');

        await expectLater(
          ImportacionService(auditoria: auditoria).ejecutar(
            tipoArchivo: 'finalizaciones',
            nombreArchivo: 'lms.xlsx',
            procesar: () async => throw error,
          ),
          throwsA(same(error)),
        );

        expect(auditoria.registros.single.estado, EstadoImportacion.fallida);
        expect(auditoria.registros.single.errores.single, contains('Curso'));
      },
    );

    test(
      'Un error de refresh conserva una sola auditoría completada',
      () async {
        final auditoria = _Auditoria();
        var refrescos = 0;

        await expectLater(
          ImportacionService(auditoria: auditoria).ejecutar(
            tipoArchivo: 'cursos_lms',
            nombreArchivo: 'cursos.csv',
            procesar: () async => const ResultadoUpsert(
              registrosProcesados: 25,
              insertados: 0,
              actualizados: 25,
            ),
            refrescar: () async {
              refrescos++;
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

        expect(refrescos, 1);
        final registro = auditoria.registros.single;
        expect(registro.estado, EstadoImportacion.completada);
        expect(registro.registrosProcesados, 25);
        expect(registro.insertados, 0);
        expect(registro.actualizados, 25);
        expect(registro.errores, isEmpty);
      },
    );

    test(
      'El modo sin auditoría mantiene la persistencia y el refresh',
      () async {
        var refrescos = 0;
        final resultado = await const ImportacionService().ejecutar(
          tipoArchivo: 'cursos_lms',
          nombreArchivo: 'local.csv',
          procesar: () async => const ResultadoUpsert(
            registrosProcesados: 1,
            insertados: 1,
            actualizados: 0,
          ),
          refrescar: () async => refrescos++,
        );

        expect(resultado.insertados, 1);
        expect(resultado.actualizados, 0);
        expect(refrescos, 1);
      },
    );
  });

  group('Feedback de las importaciones', () {
    testWidgets('Loading inmediato, bloqueo por sección y cancelación segura', (
      tester,
    ) async {
      final seleccion = Completer<FilePickerResult?>();
      final selector = _SelectorArchivo(() => seleccion.future);
      FilePicker.platform = selector;
      final auditoria = _Auditoria();
      final cursos = _Cursos();
      await _mostrarConfiguracion(tester, cursos: cursos, auditoria: auditoria);

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      _verificarLoading(tester, 'cursos', true);
      expect(_boton(tester, 'nomina').onPressed, isNotNull);
      expect(_boton(tester, 'horas').onPressed, isNotNull);
      expect(_boton(tester, 'finalizaciones').onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      expect(selector.llamadas, 1);
      expect(cursos.upserts, 0);

      seleccion.complete(null);
      await tester.pumpAndSettle();
      _verificarLoading(tester, 'cursos', false);
      expect(auditoria.registros, isEmpty);
      expect(cursos.upserts, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Loading dura hasta persistencia, auditoría y refresh reales', (
      tester,
    ) async {
      FilePicker.platform = _SelectorArchivo(
        () async => _csv('cursos.csv', _catalogo),
      );
      final persistencia = Completer<ResultadoUpsert>();
      final auditar = Completer<void>();
      final refresh = Completer<List<Curso>>();
      final cursos = _Cursos()..persistencia = persistencia;
      final auditoria = _Auditoria()..alRegistrar = (_) => auditar.future;
      final container = await _mostrarConfiguracion(
        tester,
        cursos: cursos,
        auditoria: auditoria,
      );
      final escucha = container.listen(cursosProvider, (_, _) {});
      addTearDown(escucha.close);
      await container.read(cursosProvider.future);
      cursos.consultaPendiente = refresh;

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      _verificarLoading(tester, 'cursos', true);
      expect(cursos.upserts, 1);
      expect(auditoria.registros, isEmpty);
      expect(cursos.consultas, 2);
      expect(find.byType(SnackBar), findsNothing);

      persistencia.complete(
        const ResultadoUpsert(
          registrosProcesados: 1,
          insertados: 0,
          actualizados: 1,
        ),
      );
      await tester.pump();
      _verificarLoading(tester, 'cursos', true);
      expect(auditoria.registros.single.estado, EstadoImportacion.completada);
      expect(auditoria.registros.single.insertados, 0);
      expect(auditoria.registros.single.actualizados, 1);
      expect(cursos.consultas, 2);
      expect(find.byType(SnackBar), findsNothing);

      auditar.complete();
      await tester.pump();
      _verificarLoading(tester, 'cursos', true);
      expect(cursos.consultas, 3);
      expect(find.byType(SnackBar), findsNothing);

      refresh.complete(List.of(cursos.guardados));
      await tester.pumpAndSettle();
      _verificarLoading(tester, 'cursos', false);
      expect(
        find.text('Se cargaron 1 cursos desde cursos.csv.'),
        findsOneWidget,
      );
      expect(cursos.guardados.single.id, '107');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Error de Supabase libera loading, audita y no refresca', (
      tester,
    ) async {
      FilePicker.platform = _SelectorArchivo(
        () async => _csv('cursos.csv', _catalogo),
      );
      final persistencia = Completer<ResultadoUpsert>();
      final cursos = _Cursos()..persistencia = persistencia;
      final auditar = Completer<void>();
      final auditoria = _Auditoria()..alRegistrar = (_) => auditar.future;
      final container = await _mostrarConfiguracion(
        tester,
        cursos: cursos,
        auditoria: auditoria,
      );
      final escucha = container.listen(cursosProvider, (_, _) {});
      addTearDown(escucha.close);
      await container.read(cursosProvider.future);

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      _verificarLoading(tester, 'cursos', true);
      persistencia.completeError(StateError('Supabase rechazó el UPSERT'));
      await tester.pump();
      _verificarLoading(tester, 'cursos', true);
      expect(auditoria.registros.single.estado, EstadoImportacion.fallida);
      expect(find.byType(SnackBar), findsNothing);
      auditar.complete();
      await tester.pumpAndSettle();

      _verificarLoading(tester, 'cursos', false);
      expect(cursos.consultas, 2);
      expect(cursos.guardados, isEmpty);
      expect(auditoria.registros.single.estado, EstadoImportacion.fallida);
      expect(auditoria.registros.single.errores.single, contains('Supabase'));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Se cargaron'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Error de parsing se audita antes de cualquier UPSERT', (
      tester,
    ) async {
      FilePicker.platform = _SelectorArchivo(
        () async => _csv('sin_cursos.csv', 'Columna incorrecta\r\nDato\r\n'),
      );
      final cursos = _Cursos();
      final auditoria = _Auditoria();
      await _mostrarConfiguracion(tester, cursos: cursos, auditoria: auditoria);

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pumpAndSettle();

      _verificarLoading(tester, 'cursos', false);
      expect(cursos.upserts, 0);
      expect(cursos.consultas, 0);
      final registro = auditoria.registros.single;
      expect(registro.estado, EstadoImportacion.fallida);
      expect(registro.nombreArchivo, 'sin_cursos.csv');
      expect(registro.errores.single, contains('No se encontraron cursos'));
      expect(find.textContaining('No se encontraron cursos'), findsOneWidget);
      expect(find.textContaining('Se cargaron'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renombrar un curso refresca los nombres de horas y LMS', (
      tester,
    ) async {
      FilePicker.platform = _SelectorArchivo(
        () async => _csv('cursos.csv', _catalogo),
      );
      final cursos = _Cursos()
        ..guardados.add(
          Curso.fromJson({'id': '107', 'nombre': 'Curso anterior'}),
        );
      final horas = _Horas()
        ..leer = () => [
          CargaDeHorasCRM(
            id: 'txn-1',
            cursoId: '107',
            cursoNombre: cursos.guardados.single.nombre,
            empleadoLegajo: '10',
            fecha: DateTime.utc(2026, 10, 1),
            horasTotales: 4,
            tipo: TipoCargaDeHoras.tomada,
          ),
        ];
      final certificaciones = _Certificaciones()
        ..leer = () => [
          CertificacionMoodle(
            legajo: '10',
            cursoId: '107',
            cursoNombre: cursos.guardados.single.nombre,
            finalizoCurso: true,
            fechaFinalizacion: DateTime.utc(2026, 10, 1),
          ),
        ];
      final auditoria = _Auditoria();
      final container = await _mostrarConfiguracion(
        tester,
        cursos: cursos,
        auditoria: auditoria,
        horas: horas,
        certificaciones: certificaciones,
      );
      final escuchaHoras = container.listen(
        cargasDeHorasCRMProvider,
        (_, _) {},
      );
      final escuchaLms = container.listen(
        certificacionesMoodleProvider,
        (_, _) {},
      );
      addTearDown(escuchaHoras.close);
      addTearDown(escuchaLms.close);
      expect(
        (await container.read(
          cargasDeHorasCRMProvider.future,
        )).single.cursoNombre,
        'Curso anterior',
      );
      expect(
        (await container.read(
          certificacionesMoodleProvider.future,
        )).single.cursoNombre,
        'Curso anterior',
      );
      expect(horas.consultas, 1);
      expect(certificaciones.consultas, 1);

      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pumpAndSettle();

      _verificarLoading(tester, 'cursos', false);
      expect(horas.consultas, greaterThan(1));
      expect(certificaciones.consultas, 2);
      expect(
        (await container.read(
          cargasDeHorasCRMProvider.future,
        )).single.cursoNombre,
        'Curso de prueba',
      );
      expect(
        (await container.read(
          certificacionesMoodleProvider.future,
        )).single.cursoNombre,
        'Curso de prueba',
      );
      expect(auditoria.registros.single.estado, EstadoImportacion.completada);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Abandonar la pantalla no interrumpe auditoría ni refresh', (
      tester,
    ) async {
      FilePicker.platform = _SelectorArchivo(
        () async => _csv('cursos.csv', _catalogo),
      );
      final persistencia = Completer<ResultadoUpsert>();
      final cursos = _Cursos()..persistencia = persistencia;
      final horas = _Horas();
      final certificaciones = _Certificaciones();
      final auditoria = _Auditoria();
      final container = await _mostrarConfiguracion(
        tester,
        cursos: cursos,
        auditoria: auditoria,
        horas: horas,
        certificaciones: certificaciones,
      );
      final escuchaCursos = container.listen(cursosProvider, (_, _) {});
      final escuchaHoras = container.listen(
        cargasDeHorasCRMProvider,
        (_, _) {},
      );
      final escuchaLms = container.listen(
        certificacionesMoodleProvider,
        (_, _) {},
      );
      addTearDown(escuchaCursos.close);
      addTearDown(escuchaHoras.close);
      addTearDown(escuchaLms.close);
      await Future.wait([
        container.read(cursosProvider.future),
        container.read(cargasDeHorasCRMProvider.future),
        container.read(certificacionesMoodleProvider.future),
      ]);
      final router = GoRouter.of(
        tester.element(find.byType(ConfiguracionScreen)),
      );
      await tester.tap(find.byKey(const Key('importar_cursos')));
      await tester.pump();
      _verificarLoading(tester, 'cursos', true);
      expect(cursos.upserts, 1);

      router.go('/otra');
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionScreen), findsNothing);
      expect(find.text('Otra pantalla'), findsOneWidget);
      expect(auditoria.registros, isEmpty);
      expect(cursos.consultas, 2);

      persistencia.complete(
        const ResultadoUpsert(
          registrosProcesados: 1,
          insertados: 1,
          actualizados: 0,
        ),
      );
      await tester.pumpAndSettle();

      expect(auditoria.registros.single.estado, EstadoImportacion.completada);
      expect(auditoria.registros.single.insertados, 1);
      expect(cursos.consultas, 3);
      expect(horas.consultas, greaterThan(1));
      expect(certificaciones.consultas, 2);
      expect(
        (await container.read(cursosProvider.future)).single.nombre,
        'Curso de prueba',
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Refresh fallido libera loading sin duplicar auditoría ni éxito',
      (tester) async {
        FilePicker.platform = _SelectorArchivo(
          () async => _csv('cursos.csv', _catalogo),
        );
        final cursos = _Cursos();
        final auditoria = _Auditoria();
        final container = await _mostrarConfiguracion(
          tester,
          cursos: cursos,
          auditoria: auditoria,
        );
        final escucha = container.listen(cursosProvider, (_, _) {});
        addTearDown(escucha.close);
        await container.read(cursosProvider.future);
        final refresh = Completer<List<Curso>>();
        cursos.consultaPendiente = refresh;

        await tester.tap(find.byKey(const Key('importar_cursos')));
        await tester.pump();
        _verificarLoading(tester, 'cursos', true);
        expect(cursos.guardados.single.id, '107');
        expect(auditoria.registros.single.estado, EstadoImportacion.completada);
        refresh.completeError(StateError('GET de cursos no disponible'));
        await tester.pumpAndSettle();

        _verificarLoading(tester, 'cursos', false);
        expect(auditoria.registros.single.estado, EstadoImportacion.completada);
        expect(auditoria.registros.single.insertados, 1);
        expect(find.textContaining('Los datos se guardaron'), findsOneWidget);
        expect(find.textContaining('Se cargaron'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Nómina repetida cuenta filas y escribe una vez por legajo', (
      tester,
    ) async {
      FilePicker.platform = _SelectorArchivo(
        () async => _csv(
          'nomina_repetida.csv',
          'legajo,nombre,apellido,seniority,sector,correo,fechaIngreso\r\n'
              '10,Ana,Pérez,Senior,Producto,ana@example.com,01/10/2026\r\n'
              '10,Ana,Pérez,Senior,Producto,ana@example.com,01/10/2026\r\n',
        ),
      );
      final empleados = _Empleados();
      final cursos = _Cursos();
      final auditoria = _Auditoria();
      await _mostrarConfiguracion(
        tester,
        cursos: cursos,
        auditoria: auditoria,
        empleados: empleados,
      );

      await tester.tap(find.byKey(const Key('importar_nomina')));
      await tester.pumpAndSettle();

      _verificarLoading(tester, 'nomina', false);
      expect(empleados.guardados, 1);
      expect(empleados.lotes.single.single.legajo, '10');
      expect(empleados.empleadosPorLegajo.keys, ['10']);
      final registro = auditoria.registros.single;
      expect(registro.estado, EstadoImportacion.completada);
      expect(registro.registrosProcesados, 2);
      expect(registro.insertados, 1);
      expect(registro.actualizados, 0);
      expect(
        find.text('Se importaron 2 registros desde nomina_repetida.csv.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Fecha inválida de nómina se rechaza, audita y no refresca', (
      tester,
    ) async {
      FilePicker.platform = _SelectorArchivo(
        () async => _csv(
          'nomina_invalida.csv',
          'legajo,nombre,apellido,seniority,sector,correo,fechaIngreso\r\n'
              '10,Ana,Pérez,Senior,Producto,ana@example.com,31/02/2026\r\n',
        ),
      );
      final empleados = _Empleados();
      final cursos = _Cursos();
      final auditoria = _Auditoria();
      final container = await _mostrarConfiguracion(
        tester,
        cursos: cursos,
        auditoria: auditoria,
        empleados: empleados,
      );
      final escucha = container.listen(empleadosProvider, (_, _) {});
      addTearDown(escucha.close);
      await container.read(empleadosProvider.future);

      await tester.tap(find.byKey(const Key('importar_nomina')));
      await tester.pumpAndSettle();

      _verificarLoading(tester, 'nomina', false);
      expect(empleados.guardados, 0);
      expect(empleados.consultas, 1);
      expect(cursos.upserts, 0);
      final registro = auditoria.registros.single;
      expect(registro.estado, EstadoImportacion.fallida);
      expect(registro.errores.single, contains('31/02/2026'));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Se importaron'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
