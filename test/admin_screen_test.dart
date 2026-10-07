import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/domain/repositorios/usuarios_autorizados_repository.dart';
import 'package:app_finnegans/presentation/admin_screen.dart';
import 'package:app_finnegans/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
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

Future<ProviderContainer> _mostrarPanel(
  WidgetTester tester, {
  required AccesoAdmin acceso,
  _UsuariosFake? repositorio,
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
}
