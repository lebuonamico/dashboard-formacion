import 'package:app_finnegans/core/theme/app_theme.dart';
import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/features/auth/presentation/login_screen.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthState, AuthUser;
import 'package:app_finnegans/features/auth/data/supabase_auth_repository.dart';
import 'package:app_finnegans/features/auth/data/access_rejection.dart';

const _deniedMessage = unauthorizedAccessMessage;

Map<String, dynamic> _sessionJson({String? email = 'test@example.com'}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${encode({'sub': 'test-user', 'aud': 'authenticated', 'iat': now, 'exp': now + 3600})}.'
        'test-signature',
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': 'test-user',
      'aud': 'authenticated',
      'email': email,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

http.Response _rows(http.Request request, List<Map<String, dynamic>> rows) =>
    http.Response(
      jsonEncode(rows),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );

class _AuthFixture {
  final requests = <http.Request>[];
  late final SupabaseClient client;
  Future<http.Response> Function(http.Request) authorization;

  _AuthFixture({
    required this.authorization,
    bool registerDisposal = true,
    String? email = 'test@example.com',
  }) {
    client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/rest/v1/usuarios_autorizados') {
          return authorization(request);
        }
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode(_sessionJson(email: email)),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/auth/v1/logout') {
          return http.Response('', 204, request: request);
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      }),
    );
    if (registerDisposal) addTearDown(client.dispose);
  }

  List<http.Request> get authorizationRequests => requests
      .where((request) => request.url.path == '/rest/v1/usuarios_autorizados')
      .toList();

  List<http.Request> get logoutRequests => requests
      .where((request) => request.url.path == '/auth/v1/logout')
      .toList();

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-password',
    );
  }
}

_Auth _controller(SupabaseClient client) {
  final auth = _Auth(client);
  addTearDown(auth.dispose);
  return auth;
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('La operación de autenticación no terminó.');
}

/// Same surface the tests used before: reads the current [AuthState] and
/// forwards the actions to [AuthNotifier].
class _Auth extends ChangeNotifier {
  final ProviderContainer container;
  late final ProviderSubscription<AuthState> _subscription;

  _Auth(SupabaseClient? client)
    : container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            client == null ? null : SupabaseAuthRepository(client),
          ),
        ],
      ) {
    _subscription = container.listen(authProvider, (_, _) => notifyListeners());
  }

  AuthState get _state => container.read(authProvider);
  AuthNotifier get _notifier => container.read(authProvider.notifier);

  bool get enabled => _state.enabled;
  bool get hasValidSession => _state.hasValidSession;
  bool get isAuthorized => _state.isAuthorized;
  bool get isValidatingAuthorization => _state.isValidatingAuthorization;
  bool get isSigningIn => _state.isSigningIn;
  bool get isAdmin => _state.isAdmin;
  bool get canManage => _state.canManage;
  String? get error => _state.error;
  String? get role => _state.role;
  String? get email => _state.email;

  Future<void> signInWithGoogle() => _notifier.signInWithGoogle();
  Future<void> signOut() => _notifier.signOut();
  Future<void> validateAuthorization() => _notifier.validateAuthorization();
  String? redirect(String path) => authRedirect(_state, path);

  @override
  void dispose() {
    _subscription.close();
    container.dispose();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(clearAccessRejection);

  test(
    'Usuario admin autoriza la sesión y habilita el panel de administración',
    () async {
      final fixture = _AuthFixture(
        authorization: (request) async => _rows(request, [
          {'email': 'test@example.com', 'activo': true, 'rol': 'admin'},
        ]),
      );
      final auth = _controller(fixture.client);

      await fixture.signIn();
      await _waitUntil(() => auth.isAuthorized);

      expect(auth.hasValidSession, isTrue);
      expect(auth.isValidatingAuthorization, isFalse);
      expect(auth.role, 'admin');
      expect(auth.isAdmin, isTrue);
      expect(auth.email, 'test@example.com');
      expect(auth.error, isNull);
      expect(auth.redirect('/login'), '/dashboard');
      expect(auth.redirect('/configuracion'), isNull);
      expect(auth.redirect('/admin'), isNull);
      expect(fixture.logoutRequests, isEmpty);
      final request = fixture.authorizationRequests.single;
      expect(request.method, 'GET');
      expect(request.url.queryParameters['email'], 'eq.test@example.com');
      expect(
        request.url.queryParameters['select'],
        'activo,rol,ff_eliminar,ff_bloqueo',
      );
      expect(request.headers['accept-profile'], 'public');
      expect(request.headers['authorization'], startsWith('Bearer '));

      await auth.signOut();
      expect(auth.isAuthorized, isFalse);
      expect(auth.role, isNull);
      expect(auth.isAdmin, isFalse);
      expect(auth.email, isNull);
      expect(auth.redirect('/dashboard'), '/login');
    },
  );

  test(
    'Academia entra al panel y a Configuración como el Administrador',
    () async {
      final fixture = _AuthFixture(
        authorization: (request) async => _rows(request, [
          {'email': 'test@example.com', 'activo': true, 'rol': 'academia'},
        ]),
      );
      final auth = _controller(fixture.client);

      await fixture.signIn();
      await _waitUntil(() => auth.isAuthorized);

      expect(auth.isAdmin, isFalse);
      expect(auth.canManage, isTrue);
      expect(auth.redirect('/admin'), isNull);
      expect(auth.redirect('/dashboard'), isNull);
      expect(auth.redirect('/configuracion'), isNull);
      expect(auth.redirect('/areas'), isNull);
    },
  );

  test('Un usuario de área no entra al panel ni a Configuración', () async {
    final fixture = _AuthFixture(
      authorization: (request) async => _rows(request, [
        {'email': 'test@example.com', 'activo': true, 'rol': 'area'},
      ]),
    );
    final auth = _controller(fixture.client);

    await fixture.signIn();
    await _waitUntil(() => auth.isAuthorized);

    expect(auth.canManage, isFalse);
    expect(auth.redirect('/admin'), '/dashboard');
    expect(auth.redirect('/configuracion'), '/dashboard');
    expect(auth.redirect('/areas'), isNull);
    expect(auth.redirect('/areas/SERVICIOS'), isNull);
    expect(auth.redirect('/equipos'), isNull);
  });

  test('Un líder no ve Áreas pero sí el detalle de sus equipos', () async {
    final fixture = _AuthFixture(
      authorization: (request) async => _rows(request, [
        {'email': 'test@example.com', 'activo': true, 'rol': 'lider'},
      ]),
    );
    final auth = _controller(fixture.client);

    await fixture.signIn();
    await _waitUntil(() => auth.isAuthorized);

    expect(auth.canManage, isFalse);
    expect(auth.redirect('/admin'), '/dashboard');
    expect(auth.redirect('/configuracion'), '/dashboard');
    expect(auth.redirect('/areas'), '/equipos');
    expect(auth.redirect('/areas/SERVICIOS'), '/equipos');
    expect(auth.redirect('/areas/SERVICIOS/equipos/SOPORTE'), isNull);
    expect(auth.redirect('/equipos'), isNull);
    expect(auth.redirect('/empleados/2001'), isNull);
  });

  test('Un rol desconocido no concede el panel de administración', () async {
    final fixture = _AuthFixture(
      authorization: (request) async => _rows(request, [
        {'email': 'test@example.com', 'activo': true, 'rol': 'superadmin'},
      ]),
    );
    final auth = _controller(fixture.client);

    await fixture.signIn();
    await _waitUntil(() => auth.isAuthorized);

    expect(auth.role, 'superadmin');
    expect(auth.isAdmin, isFalse);
    expect(auth.canManage, isFalse);
    expect(auth.redirect('/admin'), '/dashboard');
    expect(auth.redirect('/configuracion'), '/dashboard');
  });

  for (final entry in <String, List<Map<String, dynamic>>>{
    'Usuario ausente de la lista': [],
    'Usuario con activo=false': [
      {'email': 'test@example.com', 'activo': false, 'rol': 'admin'},
    ],
    'Usuario bloqueado': [
      {
        'email': 'test@example.com',
        'activo': true,
        'rol': 'admin',
        'ff_bloqueo': '2026-10-03T14:30:00+00:00',
      },
    ],
    'Usuario eliminado': [
      {
        'email': 'test@example.com',
        'activo': true,
        'rol': 'admin',
        'ff_eliminar': '2026-10-03T14:30:00+00:00',
      },
    ],
  }.entries) {
    test('${entry.key} cierra sesión y muestra el motivo', () async {
      final fixture = _AuthFixture(
        authorization: (request) async => _rows(request, entry.value),
      );
      final auth = _controller(fixture.client);

      await fixture.signIn();
      await _waitUntil(
        () => auth.error == _deniedMessage && !auth.isValidatingAuthorization,
      );

      expect(auth.isAuthorized, isFalse);
      expect(auth.hasValidSession, isFalse);
      expect(fixture.client.auth.currentSession, isNull);
      expect(auth.role, isNull);
      expect(auth.redirect('/dashboard'), '/login');
      expect(auth.redirect('/login'), isNull);
      final logout = fixture.logoutRequests.single;
      expect(logout.method, 'POST');
      expect(logout.headers['authorization'], startsWith('Bearer '));
      await Future<void>.delayed(Duration.zero);
      expect(
        auth.error,
        _deniedMessage,
        reason: 'SignedOut conserva el motivo',
      );
    });
  }

  test(
    'Error de consulta bloquea acceso y permite reintentar con la sesión',
    () async {
      final fixture = _AuthFixture(
        authorization: (request) async => http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied'}),
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      );
      final auth = _controller(fixture.client);

      await fixture.signIn();
      await _waitUntil(
        () => auth.error != null && !auth.isValidatingAuthorization,
      );

      expect(auth.hasValidSession, isTrue);
      expect(auth.isAuthorized, isFalse);
      expect(auth.role, isNull);
      expect(auth.error, isNot(_deniedMessage));
      expect(auth.error, contains('No se pudo validar la autorización'));
      expect(auth.redirect('/dashboard'), '/login');
      expect(auth.redirect('/login'), isNull);
      expect(fixture.logoutRequests, isEmpty);

      fixture.authorization = (request) async => _rows(request, [
        {'email': 'test@example.com', 'activo': true, 'rol': 'usuario'},
      ]);
      await auth.signInWithGoogle();

      expect(auth.isAuthorized, isTrue);
      expect(auth.role, 'usuario');
      expect(auth.error, isNull);
      expect(auth.redirect('/login'), '/dashboard');
      expect(fixture.authorizationRequests, hasLength(2));
    },
  );

  test(
    'Sesión restaurada permanece bloqueada hasta completar la consulta',
    () async {
      final started = Completer<http.Request>();
      final response = Completer<http.Response>();
      final fixture = _AuthFixture(
        authorization: (request) {
          started.complete(request);
          return response.future;
        },
      );
      await fixture.client.auth.setInitialSession(jsonEncode(_sessionJson()));
      final auth = _controller(fixture.client);

      expect(auth.hasValidSession, isTrue);
      expect(auth.isValidatingAuthorization, isTrue);
      expect(auth.isAuthorized, isFalse);
      expect(auth.role, isNull);
      expect(auth.redirect('/dashboard'), '/login');
      expect(auth.redirect('/login'), isNull);
      final request = await started.future;
      response.complete(
        _rows(request, [
          {'email': 'test@example.com', 'activo': true, 'rol': 'usuario'},
        ]),
      );
      await _waitUntil(() => auth.isAuthorized);

      expect(auth.isValidatingAuthorization, isFalse);
      expect(auth.redirect('/login'), '/dashboard');
    },
  );

  test(
    'Logout durante validación descarta una respuesta tardía autorizada',
    () async {
      final started = Completer<http.Request>();
      final response = Completer<http.Response>();
      final fixture = _AuthFixture(
        authorization: (request) {
          started.complete(request);
          return response.future;
        },
      );
      final auth = _controller(fixture.client);
      await fixture.signIn();
      final request = await started.future;

      await auth.signOut();
      response.complete(
        _rows(request, [
          {'email': 'test@example.com', 'activo': true, 'rol': 'admin'},
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(auth.hasValidSession, isFalse);
      expect(auth.isAuthorized, isFalse);
      expect(auth.isValidatingAuthorization, isFalse);
      expect(auth.role, isNull);
      expect(auth.redirect('/dashboard'), '/login');
    },
  );

  test(
    'Una sesión sin email se rechaza y cierra sin consultar la tabla',
    () async {
      final fixture = _AuthFixture(
        email: null,
        authorization: (request) async => _rows(request, []),
      );
      final auth = _controller(fixture.client);
      await fixture.signIn();
      await _waitUntil(() => auth.error == _deniedMessage);

      expect(auth.isAuthorized, isFalse);
      expect(auth.hasValidSession, isFalse);
      expect(fixture.authorizationRequests, isEmpty);
      expect(fixture.logoutRequests, hasLength(1));
    },
  );

  testWidgets(
    'Login muestra loading y nunca construye Dashboard antes del gate',
    (tester) async {
      final started = Completer<http.Request>();
      final response = Completer<http.Response>();
      final fixture = (await tester.runAsync(
        () async => _AuthFixture(
          registerDisposal: false,
          authorization: (request) {
            started.complete(request);
            return response.future;
          },
        ),
      ))!;
      addTearDown(() => tester.runAsync(fixture.client.dispose));
      final auth = _Auth(fixture.client);
      var dashboardBuilds = 0;
      final router = GoRouter(
        initialLocation: '/dashboard',
        refreshListenable: auth,
        redirect: (_, state) => auth.redirect(state.uri.path),
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) {
              dashboardBuilds++;
              return const Scaffold(body: Text('Dashboard autorizado'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: auth.container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(0.7)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(dashboardBuilds, 0);
      await tester.runAsync(fixture.signIn);
      final request = await tester.runAsync(() => started.future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(auth.isValidatingAuthorization, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(dashboardBuilds, 0);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');

      await tester.runAsync(() async {
        response.complete(
          _rows(request!, [
            {'email': 'test@example.com', 'activo': true, 'rol': 'usuario'},
          ]),
        );
        await _waitUntil(() => auth.isAuthorized);
      });
      await tester.pumpAndSettle();

      expect(find.text('Dashboard autorizado'), findsOneWidget);
      expect(dashboardBuilds, greaterThan(0));
      expect(router.routerDelegate.currentConfiguration.uri.path, '/dashboard');
      expect(tester.takeException(), isNull);
    },
  );
}
