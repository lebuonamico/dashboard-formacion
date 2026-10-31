import 'dart:async';

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';
import 'package:app_finnegans/features/admin/presentation/admin_screen.dart';
import 'package:app_finnegans/features/admin/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/admin/presentation/providers/authorized_users_repository_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_repository_provider.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_actions_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/org_structure_labels.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user_service.dart';

final _creation = DateTime.utc(2026, 1, 15, 10);
final _stamp = DateTime.utc(2026, 10, 3, 14, 30);

class _FakeUsers implements AuthorizedUsersRepository {
  List<AuthorizedUser> users;
  final created = <AuthorizedUser>[];
  final saved = <AuthorizedUser>[];
  Object? saveError;
  Completer<void>? gate;

  _FakeUsers(this.users);

  @override
  Future<List<AuthorizedUser>> getUsers() async => users;

  @override
  Future<void> create(AuthorizedUser user) async {
    created.add(user);
    users = [...users, user];
  }

  @override
  Future<void> save(AuthorizedUser user) async {
    await gate?.future;
    final error = saveError;
    if (error != null) throw error;
    saved.add(user);
    users = [
      for (final current in users)
        if (current.email == user.email) user else current,
    ];
  }
}

AuthorizedUser _user({
  required String email,
  String role = 'teamLead',
  DateTime? blockedAt,
  DateTime? deletedAt,
}) => AuthorizedUser(
  email: email,
  role: role,
  isActive: blockedAt == null && deletedAt == null,
  createdAt: _creation,
  blockedAt: blockedAt,
  deletedAt: deletedAt,
);

/// Estructura en memoria que registra cada llamada como texto.
class _FakeStructure implements OrgStructureRepository {
  OrgStructure structure;
  final calls = <String>[];
  Completer<void>? gate;

  _FakeStructure(this.structure);

  @override
  Future<OrgStructure> getStructure() async => structure;

  @override
  Future<void> registerMissing(PayrollGaps missing) async =>
      calls.add('faltantes');

  @override
  Future<void> assignLeadersArea(String areaId, Set<String> emails) async =>
      calls.add('lideresArea $areaId ${(emails.toList()..sort()).join(',')}');

  @override
  Future<void> assignTeamLeaders(String teamId, Set<String> emails) async {
    await gate?.future;
    calls.add('lideresEquipo $teamId ${(emails.toList()..sort()).join(',')}');
  }
}

/// PRODUCTOS TECNOLÓGICOS con PLATAFORMA CORE y un equipo que la nómina ya
/// no trae (INFRA), y SERVICIOS sin equipos.
OrgStructure _structurePanel() => const OrgStructure(
  areas: [
    Area(
      id: '1',
      name: 'PRODUCTOS TECNOLÓGICOS',
      leaders: {'area@finnegans.com'},
    ),
    Area(id: '2', name: 'SERVICIOS'),
  ],
  teams: [
    Team(
      id: '10',
      areaId: '1',
      name: 'PLATAFORMA CORE',
      leaders: {'lider@finnegans.com'},
    ),
    Team(id: '11', areaId: '1', name: 'INFRA'),
  ],
);

Employee _employee(
  String employeeId,
  String area,
  String team, {
  String? email,
  bool active = true,
}) => Employee(
  employeeId: employeeId,
  firstName: 'Persona',
  lastName: employeeId,
  seniority: Seniority.junior1,
  area: area,
  email: email ?? 'persona$employeeId@finnegans.com',
  team: team,
  isActive: active,
);

Future<ProviderContainer> _showPanel(
  WidgetTester tester, {
  AccessAdmin? access,
  _FakeUsers? repository,
  _FakeStructure? structure,
  List<Employee> employees = const [],
}) async {
  tester.view.physicalSize = const Size(1800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      if (access != null) accessAdminProvider.overrideWithValue(access),
      if (repository != null)
        authorizedUsersRepositoryProvider.overrideWithValue(repository),
      if (structure != null) ...[
        sessionDataProvider.overrideWithValue((
          enabled: true,
          email: 'admin@finnegans.com',
          role: 'admin',
        )),
        orgStructureRepositoryProvider.overrideWithValue(structure),
        // Los conteos y Pertenece a salen de la nómina.
        employeesProvider.overrideWith((ref) async => employees),
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

OutlinedButton _button(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.byKey(Key(key)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Un no-admin ve el aviso y ninguna acción', (tester) async {
    await _showPanel(tester, access: AccessAdmin.denied);

    expect(find.text('No tenés permiso para ver esta sección'), findsOneWidget);
    expect(find.byKey(const Key('admin_crear')), findsNothing);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('En modo local el panel funciona con los usuarios en memoria', (
    tester,
  ) async {
    await _showPanel(tester);

    expect(find.text('admin@finnegans-demo.com'), findsOneWidget);
    expect(find.byKey(const Key('admin_crear')), findsOneWidget);
  });

  testWidgets('Las acciones se habilitan al seleccionar una fila', (
    tester,
  ) async {
    final repository = _FakeUsers([
      _user(email: 'ana@finnegans.com', role: 'academy'),
      _user(email: 'beto@finnegans.com'),
    ]);
    await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );

    expect(_button(tester, 'admin_crear').onPressed, isNotNull);
    expect(_button(tester, 'admin_cambiar_rol').onPressed, isNull);
    expect(_button(tester, 'admin_bloquear').onPressed, isNull);
    expect(_button(tester, 'admin_eliminar').onPressed, isNull);
    expect(
      find.text(
        'Seleccioná un usuario de la lista para habilitar las acciones.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('ana@finnegans.com'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccionado: ana@finnegans.com'), findsOneWidget);
    expect(_button(tester, 'admin_cambiar_rol').onPressed, isNotNull);
    expect(_button(tester, 'admin_bloquear').onPressed, isNotNull);
    expect(_button(tester, 'admin_eliminar').onPressed, isNotNull);

    await tester.tap(find.text('ana@finnegans.com'));
    await tester.pumpAndSettle();

    expect(_button(tester, 'admin_cambiar_rol').onPressed, isNull);
  });

  group('Protección anti-autobloqueo', () {
    Future<void> mountBar(
      WidgetTester tester, {
      required AuthorizedUser selected,
      required String? ownEmail,
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
              selected: selected,
              outsideFilter: false,
              pendingAction: null,
              ownEmail: ownEmail,
              onCreate: () {},
              onRoleChange: () {},
              onBlock: () {},
              onUnblock: () {},
              onDelete: () {},
              onRestore: () {},
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
      await mountBar(
        tester,
        selected: _user(email: 'yo@finnegans.com', role: 'admin'),
        ownEmail: 'YO@finnegans.com',
      );

      expect(_button(tester, 'admin_cambiar_rol').onPressed, isNull);
      expect(_button(tester, 'admin_bloquear').onPressed, isNull);
      expect(_button(tester, 'admin_eliminar').onPressed, isNull);
      expect(_button(tester, 'admin_crear').onPressed, isNotNull);
      expect(
        find.text('Es tu propio usuario: no podés modificarlo desde acá.'),
        findsOneWidget,
      );
    });

    testWidgets('Habilita todo sobre la fila de otro', (tester) async {
      await mountBar(
        tester,
        selected: _user(email: 'otro@finnegans.com'),
        ownEmail: 'yo@finnegans.com',
      );

      expect(_button(tester, 'admin_cambiar_rol').onPressed, isNotNull);
      expect(_button(tester, 'admin_bloquear').onPressed, isNotNull);
      expect(_button(tester, 'admin_eliminar').onPressed, isNotNull);
    });

    testWidgets('A un eliminado le ofrece restaurar, no bloquear', (
      tester,
    ) async {
      await mountBar(
        tester,
        selected: _user(email: 'otro@finnegans.com', deletedAt: _stamp),
        ownEmail: 'yo@finnegans.com',
      );

      expect(find.byKey(const Key('admin_restaurar')), findsOneWidget);
      expect(find.byKey(const Key('admin_eliminar')), findsNothing);
      expect(_button(tester, 'admin_bloquear').onPressed, isNull);
    });
  });

  testWidgets('Bloquear sella la fecha y refresca la tabla', (tester) async {
    final repository = _FakeUsers([_user(email: 'ana@finnegans.com')]);
    final container = await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );
    container
        .read(selectedAdminEmailProvider.notifier)
        .select('ana@finnegans.com');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_bloquear')));
    await tester.pumpAndSettle();
    expect(find.text('Bloquear usuario'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_confirmar')));
    await tester.pumpAndSettle();

    final saved = repository.saved.single;
    expect(saved.email, 'ana@finnegans.com');
    expect(saved.blockedAt, isNotNull);
    expect(saved.isActive, isFalse);
    expect(const AuthorizedUserService().status(saved), UserStatus.blocked);
    expect(find.byKey(const Key('admin_desbloquear')), findsOneWidget);
    expect(find.byKey(const Key('admin_bloquear')), findsNothing);
  });

  testWidgets('Mientras bloquea muestra el progreso y frena las acciones', (
    tester,
  ) async {
    final repository = _FakeUsers([_user(email: 'ana@finnegans.com')]);
    final gate = repository.gate = Completer<void>();
    final container = await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );
    container
        .read(selectedAdminEmailProvider.notifier)
        .select('ana@finnegans.com');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_bloquear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_confirmar')));
    await tester.pump();

    expect(find.byKey(const Key('loading_admin_bloquear')), findsOneWidget);
    expect(_button(tester, 'admin_crear').onPressed, isNull);
    expect(_button(tester, 'admin_eliminar').onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loading_admin_bloquear')), findsNothing);
    expect(find.text('Se bloqueó a ana@finnegans.com.'), findsOneWidget);
  });

  testWidgets('Un error del repositorio se muestra y no rompe', (tester) async {
    final repository = _FakeUsers([_user(email: 'ana@finnegans.com')])
      ..saveError = const FormatException(
        'El usuario ya no existe o no tenés permiso para modificarlo.',
      );
    final container = await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );
    container
        .read(selectedAdminEmailProvider.notifier)
        .select('ana@finnegans.com');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_eliminar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_confirmar')));
    await tester.pumpAndSettle();

    expect(
      find.text('El usuario ya no existe o no tenés permiso para modificarlo.'),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El alta pasa el rol elegido y selecciona al nuevo', (
    tester,
  ) async {
    final repository = _FakeUsers([]);
    final container = await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );

    await tester.tap(find.byKey(const Key('admin_crear')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin_alta_email')),
      '  Nuevo.Usuario@Finnegans.com  ',
    );
    await tester.tap(find.byKey(const Key('admin_alta_confirmar')));
    await tester.pumpAndSettle();

    final created = repository.created.single;
    expect(created.email, 'nuevo.usuario@finnegans.com');
    expect(const AuthorizedUserService().knownRole(created), UserRole.teamLead);
    expect(created.isActive, isTrue);
    expect(created.createdAt, isNotNull);
    expect(
      container.read(selectedAdminEmailProvider),
      'nuevo.usuario@finnegans.com',
    );
  });

  testWidgets('Un email inválido no cierra el diálogo ni crea nada', (
    tester,
  ) async {
    final repository = _FakeUsers([]);
    await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
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
    expect(repository.created, isEmpty);
  });

  testWidgets('El filtro por estado usa la precedencia del modelo', (
    tester,
  ) async {
    final repository = _FakeUsers([
      _user(email: 'activa@finnegans.com'),
      _user(email: 'bloqueada@finnegans.com', blockedAt: _stamp),
      _user(email: 'ambas@finnegans.com', blockedAt: _stamp, deletedAt: _stamp),
    ]);
    final container = await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );

    expect(
      container
          .read(dataFilterSelectionProvider(DataFilterScope.adminUsers))
          .values,
      isEmpty,
    );
    expect(find.text('ambas@finnegans.com'), findsOneWidget);

    container
        .read(dataFilterSelectionProvider(DataFilterScope.adminUsers).notifier)
        .select('Estado', {'Bloqueado'});
    await tester.pumpAndSettle();
    expect(find.text('bloqueada@finnegans.com'), findsOneWidget);
    expect(find.text('ambas@finnegans.com'), findsNothing);

    container
        .read(dataFilterSelectionProvider(DataFilterScope.adminUsers).notifier)
        .select('Estado', {'Eliminado'});
    await tester.pumpAndSettle();
    expect(find.text('ambas@finnegans.com'), findsOneWidget);
    expect(find.text('bloqueada@finnegans.com'), findsNothing);
  });

  testWidgets('La selección sobrevive a quedar fuera del filtro', (
    tester,
  ) async {
    final repository = _FakeUsers([
      _user(email: 'ana@finnegans.com'),
      _user(email: 'beto@finnegans.com', blockedAt: _stamp),
    ]);
    final container = await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );
    container
        .read(selectedAdminEmailProvider.notifier)
        .select('ana@finnegans.com');
    container
        .read(dataFilterSelectionProvider(DataFilterScope.adminUsers).notifier)
        .select('Estado', {'Bloqueado'});
    await tester.pumpAndSettle();

    expect(find.text('ana@finnegans.com'), findsNothing);
    expect(find.text('Seleccionado: ana@finnegans.com'), findsOneWidget);
    expect(find.text('(no aparece con los filtros actuales)'), findsOneWidget);
    expect(_button(tester, 'admin_cambiar_rol').onPressed, isNotNull);
  });

  testWidgets('Una selección que ya no existe deshabilita las acciones', (
    tester,
  ) async {
    final repository = _FakeUsers([_user(email: 'ana@finnegans.com')]);
    final container = await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );
    container
        .read(selectedAdminEmailProvider.notifier)
        .select('fantasma@finnegans.com');
    await tester.pumpAndSettle();

    expect(_button(tester, 'admin_cambiar_rol').onPressed, isNull);
    expect(_button(tester, 'admin_eliminar').onPressed, isNull);
  });

  testWidgets('Un rol desconocido se muestra crudo y marcado', (tester) async {
    final repository = _FakeUsers([
      _user(email: 'legacy@finnegans.com', role: 'usuario'),
    ]);
    await _showPanel(
      tester,
      access: AccessAdmin.allowed,
      repository: repository,
    );

    expect(find.text('usuario'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });

  test('Academia y Administrador tienen acceso al panel', () {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthNotifier(
            const AuthState(
              user: AuthUser(id: 'test-user', email: 'usuario@finnegans.com'),
              isAuthorized: true,
              role: 'academy',
            ),
          ),
        ),
        authorizedUsersRepositoryProvider.overrideWithValue(_FakeUsers([])),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(accessAdminProvider), AccessAdmin.allowed);
  });

  group('Áreas y equipos', () {
    final users = [
      _user(email: 'lider@finnegans.com'),
      _user(email: 'otro.lider@finnegans.com'),
      _user(email: 'bloqueado@finnegans.com', blockedAt: _stamp),
      _user(email: 'area@finnegans.com', role: 'areaLead'),
    ];
    final payroll = [
      _employee('1', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE'),
      _employee('2', 'productos tecnológicos', 'plataforma core'),
      _employee(
        '3',
        'PRODUCTOS TECNOLÓGICOS',
        'PLATAFORMA CORE',
        active: false,
      ),
      _employee('4', 'SERVICIOS', ''),
      // El líder de PLATAFORMA CORE figura en la nómina en SERVICIOS.
      _employee(
        '5',
        'SERVICIOS',
        'IMPLEMENTACIONES',
        email: 'Lider@finnegans.com',
      ),
      _employee('6', 'SERVICIOS', '', email: 'area@finnegans.com'),
    ];

    Future<_FakeStructure> openTab(WidgetTester tester) async {
      final structure = _FakeStructure(_structurePanel());
      await _showPanel(
        tester,
        access: AccessAdmin.allowed,
        repository: _FakeUsers(users),
        structure: structure,
        employees: payroll,
      );
      await tester.tap(find.text('Áreas y equipos'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return structure;
    }

    testWidgets('Lista las áreas y equipos de la nómina con sus conteos', (
      tester,
    ) async {
      await openTab(tester);

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
      await openTab(tester);

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
      final structure = await openTab(tester);

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

      expect(structure.calls, [
        'lideresEquipo 10 lider@finnegans.com,otro.lider@finnegans.com',
      ]);
    });

    testWidgets('Mientras guarda los líderes no deja editar otros', (
      tester,
    ) async {
      final structure = await openTab(tester);
      final gate = structure.gate = Completer<void>();
      bool enabled(String key) =>
          tester.widget<TextButton>(find.byKey(Key(key))).onPressed != null;

      await tester.tap(find.byKey(const Key('estructura_lideres_equipo_10')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('admin_lider_otro.lider@finnegans.com')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_lideres_confirmar')));
      await tester.pump();

      expect(enabled('estructura_lideres_area_1'), isFalse);
      expect(enabled('estructura_lideres_equipo_11'), isFalse);

      gate.complete();
      await tester.pumpAndSettle();
      expect(enabled('estructura_lideres_area_1'), isTrue);
      expect(
        find.text('Se actualizaron los líderes de PLATAFORMA CORE.'),
        findsOneWidget,
      );
    });

    testWidgets('Los líderes de área se eligen entre los usuarios de área', (
      tester,
    ) async {
      final structure = await openTab(tester);

      await tester.tap(find.byKey(const Key('estructura_lideres_area_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_lider_area@finnegans.com')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_lideres_confirmar')));
      await tester.pumpAndSettle();

      expect(structure.calls, ['lideresArea 2 area@finnegans.com']);
    });

    testWidgets(
      'La tabla de usuarios muestra lo que lidera y a qué pertenece',
      (tester) async {
        await _showPanel(
          tester,
          access: AccessAdmin.allowed,
          repository: _FakeUsers([
            ...users,
            _user(email: 'academia@finnegans.com', role: 'academy'),
          ]),
          structure: _FakeStructure(_structurePanel()),
          employees: payroll,
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
        expect(find.text(OrgStructureLabels.notInPayroll), findsNWidgets(2));
      },
    );
  });
}
