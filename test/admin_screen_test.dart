import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/domain/repositorios/estructura_repository.dart';
import 'package:app_finnegans/domain/repositorios/usuarios_autorizados_repository.dart';
import 'package:app_finnegans/presentation/admin_screen.dart';
import 'package:app_finnegans/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_actions_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _alta = DateTime.utc(2026, 1, 15, 10);
final _sello = DateTime.utc(2026, 10, 3, 14, 30);

class _UsuariosFake implements UsuariosAutorizadosRepository {
  List<UsuarioAutorizado> usuarios;
  final creados = <UsuarioAutorizado>[];
  final guardados = <UsuarioAutorizado>[];
  Object? errorAlGuardar;

  _UsuariosFake(this.usuarios);

  @override
  Future<List<UsuarioAutorizado>> getUsuarios() async => usuarios;

  @override
  Future<void> crear(UsuarioAutorizado usuario) async {
    creados.add(usuario);
    usuarios = [...usuarios, usuario];
  }

  @override
  Future<void> guardar(UsuarioAutorizado usuario) async {
    final error = errorAlGuardar;
    if (error != null) throw error;
    guardados.add(usuario);
    usuarios = [
      for (final actual in usuarios)
        if (actual.email == usuario.email) usuario else actual,
    ];
  }
}

UsuarioAutorizado _usuario({
  required String email,
  String rol = 'lider',
  DateTime? ffBloqueo,
  DateTime? ffEliminar,
}) => UsuarioAutorizado(
  email: email,
  rol: rol,
  activo: ffBloqueo == null && ffEliminar == null,
  ffAlta: _alta,
  ffBloqueo: ffBloqueo,
  ffEliminar: ffEliminar,
);

/// Estructura en memoria que registra cada llamada como texto.
class _EstructuraFake implements EstructuraRepository {
  EstructuraOrganizacional estructura;
  final llamadas = <String>[];

  _EstructuraFake(this.estructura);

  @override
  Future<EstructuraOrganizacional> getEstructura() async => estructura;

  @override
  Future<void> registrarFaltantes(FaltantesNomina faltantes) async =>
      llamadas.add('faltantes');

  @override
  Future<void> asignarLideresArea(String areaId, Set<String> emails) async =>
      llamadas.add(
        'lideresArea $areaId ${(emails.toList()..sort()).join(',')}',
      );

  @override
  Future<void> asignarLideresEquipo(
    String equipoId,
    Set<String> emails,
  ) async => llamadas.add(
    'lideresEquipo $equipoId ${(emails.toList()..sort()).join(',')}',
  );
}

/// PRODUCTOS TECNOLÓGICOS con PLATAFORMA CORE y un equipo que la nómina ya
/// no trae (INFRA), y SERVICIOS sin equipos.
EstructuraOrganizacional _estructuraPanel() => EstructuraOrganizacional(
  areas: [
    Area(
      id: '1',
      nombre: 'PRODUCTOS TECNOLÓGICOS',
      lideres: {'area@finnegans.com'},
    ),
    Area(id: '2', nombre: 'SERVICIOS'),
  ],
  equipos: [
    Equipo(
      id: '10',
      areaId: '1',
      nombre: 'PLATAFORMA CORE',
      lideres: {'lider@finnegans.com'},
    ),
    Equipo(id: '11', areaId: '1', nombre: 'INFRA'),
  ],
);

Empleado _empleado(
  String legajo,
  String area,
  String equipo, {
  String? mail,
  bool activo = true,
}) => Empleado(
  legajo: legajo,
  nombre: 'Persona',
  apellido: legajo,
  seniority: Seniority.junior1,
  area: area,
  mail: mail ?? 'persona$legajo@finnegans.com',
  equipo: equipo,
  activo: activo,
);

class _AuthGestor extends AuthController {
  _AuthGestor() : super(null);

  @override
  bool get esGestor => true;
}

Future<ProviderContainer> _mostrarPanel(
  WidgetTester tester, {
  required AccesoAdmin acceso,
  _UsuariosFake? repositorio,
  _EstructuraFake? estructura,
  List<Empleado> empleados = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(null)),
      accesoAdminProvider.overrideWithValue(acceso),
      usuariosAutorizadosRepositoryProvider.overrideWithValue(repositorio),
      if (estructura != null) ...[
        sesionDatosProvider.overrideWithValue((
          habilitada: true,
          email: 'admin@finnegans.com',
          rol: 'admin',
        )),
        estructuraRepositoryProvider.overrideWithValue(estructura),
        // Los conteos y Pertenece a salen de la nómina.
        empleadosProvider.overrideWith((ref) async => empleados),
      ],
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/admin',
    routes: [
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
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

OutlinedButton _boton(WidgetTester tester, String clave) =>
    tester.widget<OutlinedButton>(find.byKey(Key(clave)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Un no-admin ve el aviso y ninguna acción', (tester) async {
    await _mostrarPanel(tester, acceso: AccesoAdmin.denegado);

    expect(find.text('No tenés permiso para ver esta sección'), findsOneWidget);
    expect(find.byKey(const Key('admin_crear')), findsNothing);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('En modo local avisa que el panel no está disponible', (
    tester,
  ) async {
    await _mostrarPanel(tester, acceso: AccesoAdmin.sinSupabase);

    expect(find.text('El panel no está disponible'), findsOneWidget);
    expect(find.byKey(const Key('admin_crear')), findsNothing);
  });

  testWidgets('Las acciones se habilitan al seleccionar una fila', (
    tester,
  ) async {
    final repositorio = _UsuariosFake([
      _usuario(email: 'ana@finnegans.com', rol: 'academia'),
      _usuario(email: 'beto@finnegans.com'),
    ]);
    await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );

    expect(_boton(tester, 'admin_crear').onPressed, isNotNull);
    expect(_boton(tester, 'admin_cambiar_rol').onPressed, isNull);
    expect(_boton(tester, 'admin_bloquear').onPressed, isNull);
    expect(_boton(tester, 'admin_eliminar').onPressed, isNull);
    expect(
      find.text(
        'Seleccioná un usuario de la lista para habilitar las acciones.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('ana@finnegans.com'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccionado: ana@finnegans.com'), findsOneWidget);
    expect(_boton(tester, 'admin_cambiar_rol').onPressed, isNotNull);
    expect(_boton(tester, 'admin_bloquear').onPressed, isNotNull);
    expect(_boton(tester, 'admin_eliminar').onPressed, isNotNull);

    await tester.tap(find.text('ana@finnegans.com'));
    await tester.pumpAndSettle();

    expect(_boton(tester, 'admin_cambiar_rol').onPressed, isNull);
  });

  group('Protección anti-autobloqueo', () {
    Future<void> montarBarra(
      WidgetTester tester, {
      required UsuarioAutorizado seleccionado,
      required String? emailPropio,
    }) async {
      tester.view.physicalSize = const Size(1800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AdminActionsBar(
              seleccionado: seleccionado,
              fueraDelFiltro: false,
              accionEnCurso: null,
              emailPropio: emailPropio,
              onCrear: () {},
              onCambiarRol: () {},
              onBloquear: () {},
              onDesbloquear: () {},
              onEliminar: () {},
              onRestaurar: () {},
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.5)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Deshabilita todo sobre la propia fila', (tester) async {
      await montarBarra(
        tester,
        seleccionado: _usuario(email: 'yo@finnegans.com', rol: 'admin'),
        emailPropio: 'YO@finnegans.com',
      );

      expect(_boton(tester, 'admin_cambiar_rol').onPressed, isNull);
      expect(_boton(tester, 'admin_bloquear').onPressed, isNull);
      expect(_boton(tester, 'admin_eliminar').onPressed, isNull);
      expect(_boton(tester, 'admin_crear').onPressed, isNotNull);
      expect(
        find.text('Es tu propio usuario: no podés modificarlo desde acá.'),
        findsOneWidget,
      );
    });

    testWidgets('Habilita todo sobre la fila de otro', (tester) async {
      await montarBarra(
        tester,
        seleccionado: _usuario(email: 'otro@finnegans.com'),
        emailPropio: 'yo@finnegans.com',
      );

      expect(_boton(tester, 'admin_cambiar_rol').onPressed, isNotNull);
      expect(_boton(tester, 'admin_bloquear').onPressed, isNotNull);
      expect(_boton(tester, 'admin_eliminar').onPressed, isNotNull);
    });

    testWidgets('A un eliminado le ofrece restaurar, no bloquear', (
      tester,
    ) async {
      await montarBarra(
        tester,
        seleccionado: _usuario(email: 'otro@finnegans.com', ffEliminar: _sello),
        emailPropio: 'yo@finnegans.com',
      );

      expect(find.byKey(const Key('admin_restaurar')), findsOneWidget);
      expect(find.byKey(const Key('admin_eliminar')), findsNothing);
      expect(_boton(tester, 'admin_bloquear').onPressed, isNull);
    });
  });

  testWidgets('Bloquear sella la fecha y refresca la tabla', (tester) async {
    final repositorio = _UsuariosFake([_usuario(email: 'ana@finnegans.com')]);
    final container = await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );
    container.read(emailSeleccionadoAdminProvider.notifier).state =
        'ana@finnegans.com';
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_bloquear')));
    await tester.pumpAndSettle();
    expect(find.text('Bloquear usuario'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_confirmar')));
    await tester.pumpAndSettle();

    final guardado = repositorio.guardados.single;
    expect(guardado.email, 'ana@finnegans.com');
    expect(guardado.ffBloqueo, isNotNull);
    expect(guardado.activo, isFalse);
    expect(guardado.estado, EstadoUsuario.bloqueado);
    expect(find.byKey(const Key('admin_desbloquear')), findsOneWidget);
    expect(find.byKey(const Key('admin_bloquear')), findsNothing);
  });

  testWidgets('Un error del repositorio se muestra y no rompe', (tester) async {
    final repositorio = _UsuariosFake([_usuario(email: 'ana@finnegans.com')])
      ..errorAlGuardar = const FormatException(
        'El usuario ya no existe o no tenés permiso para modificarlo.',
      );
    final container = await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );
    container.read(emailSeleccionadoAdminProvider.notifier).state =
        'ana@finnegans.com';
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_eliminar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_confirmar')));
    await tester.pumpAndSettle();

    expect(
      find.text('El usuario ya no existe o no tenés permiso para modificarlo.'),
      findsOneWidget,
    );
    expect(repositorio.guardados, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El alta pasa el rol elegido y selecciona al nuevo', (
    tester,
  ) async {
    final repositorio = _UsuariosFake([]);
    final container = await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );

    await tester.tap(find.byKey(const Key('admin_crear')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin_alta_email')),
      '  Nuevo.Usuario@Finnegans.com  ',
    );
    await tester.tap(find.byKey(const Key('admin_alta_confirmar')));
    await tester.pumpAndSettle();

    final creado = repositorio.creados.single;
    expect(creado.email, 'nuevo.usuario@finnegans.com');
    expect(creado.rolConocido, RolUsuario.lider);
    expect(creado.activo, isTrue);
    expect(creado.ffAlta, isNotNull);
    expect(
      container.read(emailSeleccionadoAdminProvider),
      'nuevo.usuario@finnegans.com',
    );
  });

  testWidgets('Un email inválido no cierra el diálogo ni crea nada', (
    tester,
  ) async {
    final repositorio = _UsuariosFake([]);
    await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );

    await tester.tap(find.byKey(const Key('admin_crear')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin_alta_email')),
      'no-es-un-mail',
    );
    await tester.tap(find.byKey(const Key('admin_alta_confirmar')));
    await tester.pumpAndSettle();

    expect(find.text('El email no tiene un formato válido.'), findsOneWidget);
    expect(repositorio.creados, isEmpty);
  });

  testWidgets('El filtro por estado usa la precedencia del modelo', (
    tester,
  ) async {
    final repositorio = _UsuariosFake([
      _usuario(email: 'activa@finnegans.com'),
      _usuario(email: 'bloqueada@finnegans.com', ffBloqueo: _sello),
      _usuario(
        email: 'ambas@finnegans.com',
        ffBloqueo: _sello,
        ffEliminar: _sello,
      ),
    ]);
    final container = await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );

    expect(container.read(filtroEstadoAdminProvider), isNull);
    expect(find.text('ambas@finnegans.com'), findsOneWidget);

    container.read(filtroEstadoAdminProvider.notifier).state =
        EstadoUsuario.bloqueado;
    await tester.pumpAndSettle();
    expect(find.text('bloqueada@finnegans.com'), findsOneWidget);
    expect(find.text('ambas@finnegans.com'), findsNothing);

    container.read(filtroEstadoAdminProvider.notifier).state =
        EstadoUsuario.eliminado;
    await tester.pumpAndSettle();
    expect(find.text('ambas@finnegans.com'), findsOneWidget);
    expect(find.text('bloqueada@finnegans.com'), findsNothing);
  });

  testWidgets('La selección sobrevive a quedar fuera del filtro', (
    tester,
  ) async {
    final repositorio = _UsuariosFake([
      _usuario(email: 'ana@finnegans.com'),
      _usuario(email: 'beto@finnegans.com', ffBloqueo: _sello),
    ]);
    final container = await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );
    container.read(emailSeleccionadoAdminProvider.notifier).state =
        'ana@finnegans.com';
    container.read(filtroEstadoAdminProvider.notifier).state =
        EstadoUsuario.bloqueado;
    await tester.pumpAndSettle();

    expect(find.text('ana@finnegans.com'), findsNothing);
    expect(find.text('Seleccionado: ana@finnegans.com'), findsOneWidget);
    expect(find.text('(no aparece con los filtros actuales)'), findsOneWidget);
    expect(_boton(tester, 'admin_cambiar_rol').onPressed, isNotNull);
  });

  testWidgets('Una selección que ya no existe deshabilita las acciones', (
    tester,
  ) async {
    final repositorio = _UsuariosFake([_usuario(email: 'ana@finnegans.com')]);
    final container = await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );
    container.read(emailSeleccionadoAdminProvider.notifier).state =
        'fantasma@finnegans.com';
    await tester.pumpAndSettle();

    expect(_boton(tester, 'admin_cambiar_rol').onPressed, isNull);
    expect(_boton(tester, 'admin_eliminar').onPressed, isNull);
  });

  testWidgets('Un rol desconocido se muestra crudo y marcado', (tester) async {
    final repositorio = _UsuariosFake([
      _usuario(email: 'legacy@finnegans.com', rol: 'usuario'),
    ]);
    await _mostrarPanel(
      tester,
      acceso: AccesoAdmin.permitido,
      repositorio: repositorio,
    );

    expect(find.text('usuario'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });

  test('Academia y Administrador tienen acceso al panel', () {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => _AuthGestor()),
        usuariosAutorizadosRepositoryProvider.overrideWithValue(
          _UsuariosFake([]),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(accesoAdminProvider), AccesoAdmin.permitido);
  });

  group('Áreas y equipos', () {
    final usuarios = [
      _usuario(email: 'lider@finnegans.com'),
      _usuario(email: 'otro.lider@finnegans.com'),
      _usuario(email: 'bloqueado@finnegans.com', ffBloqueo: _sello),
      _usuario(email: 'area@finnegans.com', rol: 'area'),
    ];
    final nomina = [
      _empleado('1', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE'),
      _empleado('2', 'productos tecnológicos', 'plataforma core'),
      _empleado(
        '3',
        'PRODUCTOS TECNOLÓGICOS',
        'PLATAFORMA CORE',
        activo: false,
      ),
      _empleado('4', 'SERVICIOS', ''),
      // El líder de PLATAFORMA CORE figura en la nómina en SERVICIOS.
      _empleado(
        '5',
        'SERVICIOS',
        'IMPLEMENTACIONES',
        mail: 'Lider@finnegans.com',
      ),
      _empleado('6', 'SERVICIOS', '', mail: 'area@finnegans.com'),
    ];

    Future<_EstructuraFake> abrirPestana(WidgetTester tester) async {
      final estructura = _EstructuraFake(_estructuraPanel());
      await _mostrarPanel(
        tester,
        acceso: AccesoAdmin.permitido,
        repositorio: _UsuariosFake(usuarios),
        estructura: estructura,
        empleados: nomina,
      );
      await tester.tap(find.text('Áreas y equipos'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return estructura;
    }

    testWidgets('Lista las áreas y equipos de la nómina con sus conteos', (
      tester,
    ) async {
      await abrirPestana(tester);

      expect(find.text('PRODUCTOS TECNOLÓGICOS'), findsOneWidget);
      // 1 y 2 son el mismo equipo escrito distinto; 3 está dado de baja.
      expect(find.text('2 equipos · 2 colaboradores'), findsOneWidget);
      expect(find.text('PLATAFORMA CORE'), findsOneWidget);
      expect(find.text('2 colaboradores'), findsOneWidget);
      // Un equipo que la nómina ya no trae sigue listado, sin borrarse.
      expect(find.text('INFRA'), findsOneWidget);
      expect(
        find.text('Sin colaboradores activos en la nómina'),
        findsOneWidget,
      );
      expect(find.text('SERVICIOS'), findsOneWidget);
      expect(
        find.text('La nómina no trae equipos para esta área.'),
        findsOneWidget,
      );
      // Los chips usan el nombre de la nómina cuando el email figura.
      expect(find.text('Persona 5'), findsOneWidget);
      expect(find.text('Persona 6'), findsOneWidget);
    });

    testWidgets('No ofrece crear, renombrar ni eliminar', (tester) async {
      await abrirPestana(tester);

      expect(find.byKey(const Key('estructura_nueva_area')), findsNothing);
      expect(find.byKey(const Key('estructura_nuevo_equipo_1')), findsNothing);
      expect(find.byKey(const Key('estructura_menu_area_1')), findsNothing);
      expect(find.byKey(const Key('estructura_menu_equipo_10')), findsNothing);
      expect(find.text('Renombrar'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(
        find.byKey(const Key('estructura_lideres_equipo_10')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('estructura_lideres_area_1')),
        findsOneWidget,
      );
    });

    testWidgets('Los líderes de equipo se eligen entre los líderes activos', (
      tester,
    ) async {
      final estructura = await abrirPestana(tester);

      await tester.tap(find.byKey(const Key('estructura_lideres_equipo_10')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('admin_lider_lider@finnegans.com')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin_lider_otro.lider@finnegans.com')),
        findsOneWidget,
      );
      // Ni bloqueados ni usuarios con otro rol.
      expect(
        find.byKey(const Key('admin_lider_bloqueado@finnegans.com')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('admin_lider_area@finnegans.com')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('admin_lider_otro.lider@finnegans.com')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_lideres_confirmar')));
      await tester.pumpAndSettle();

      expect(estructura.llamadas, [
        'lideresEquipo 10 lider@finnegans.com,otro.lider@finnegans.com',
      ]);
    });

    testWidgets('Los líderes de área se eligen entre los usuarios de área', (
      tester,
    ) async {
      final estructura = await abrirPestana(tester);

      await tester.tap(find.byKey(const Key('estructura_lideres_area_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_lider_area@finnegans.com')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_lideres_confirmar')));
      await tester.pumpAndSettle();

      expect(estructura.llamadas, ['lideresArea 2 area@finnegans.com']);
    });

    testWidgets(
      'La tabla de usuarios muestra lo que lidera y a qué pertenece',
      (tester) async {
        await _mostrarPanel(
          tester,
          acceso: AccesoAdmin.permitido,
          repositorio: _UsuariosFake([
            ...usuarios,
            _usuario(email: 'academia@finnegans.com', rol: 'academia'),
          ]),
          estructura: _EstructuraFake(_estructuraPanel()),
          empleados: nomina,
        );

        expect(find.text('Lidera'), findsOneWidget);
        expect(find.text('Pertenece a'), findsOneWidget);
        // lider@ lidera PLATAFORMA CORE pero en la nómina está en SERVICIOS.
        expect(find.text('PLATAFORMA CORE'), findsOneWidget);
        expect(find.text('IMPLEMENTACIONES · SERVICIOS'), findsOneWidget);
        // area@ lidera PRODUCTOS TECNOLÓGICOS y en la nómina no tiene equipo.
        expect(find.text('PRODUCTOS TECNOLÓGICOS'), findsOneWidget);
        expect(find.text('Sin equipo · SERVICIOS'), findsOneWidget);
        expect(find.text('Toda la empresa'), findsOneWidget);
        // otro.lider y bloqueado tienen rol Líder, ningún equipo y no figuran.
        expect(find.text('Sin equipos asignados'), findsNWidgets(2));
        expect(
          find.text(EstructuraOrganizacional.noFiguraEnNomina),
          findsNWidgets(2),
        );
      },
    );
  });
}
