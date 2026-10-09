import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/core/app_router.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _privatePaths = [
  '/dashboard',
  '/empleados',
  '/empleados/10',
  '/cursos',
  '/configuracion',
  '/cursadas',
  '/certificaciones',
  '/metricas',
  '/areas',
  '/areas/Producto',
  '/areas/Producto/equipos/Formacion',
  '/equipos',
  '/admin',
];

Map<String, dynamic> _sessionJson({bool expired = false}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': 'test-user', 'aud': 'authenticated', 'iat': now, 'exp': now + (expired ? -3600 : 3600)})}.'
      'test-signature';
  return {
    'access_token': token,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': 'test-user',
      'aud': 'authenticated',
      'email': 'test@example.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

SupabaseClient _client({
  List<http.Request>? requests,
  bool registerDisposal = true,
}) {
  final client = SupabaseClient(
    'https://test.supabase.co',
    'public-test-key',
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: _MemoryPkceStorage(),
    ),
    httpClient: MockClient((request) async {
      requests?.add(request);
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode(_sessionJson()),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/auth/v1/logout') {
        return http.Response('', 204, request: request);
      }
      if (request.url.path == '/rest/v1/usuarios_autorizados') {
        return http.Response(
          jsonEncode([
            {'email': 'test@example.com', 'activo': true, 'rol': 'admin'},
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    }),
  );
  if (registerDisposal) addTearDown(client.dispose);
  return client;
}

AuthController _controller(SupabaseClient? client) {
  final controller = AuthController(client);
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _signIn(SupabaseClient client) => client.auth
    .signInWithPassword(email: 'test@example.com', password: 'test-password')
    .then((_) {});

Future<void> _waitForAuthorization(AuthController auth) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (auth.isAuthorized && !auth.isValidatingAuthorization) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('La sesión no completó la autorización: ${auth.error}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Redirect de Google', () {
    test('Web usa el origin actual con / final, sin query ni fragmento', () {
      for (final origin in [
        'http://localhost:3000',
        'https://formacion.example.com',
        'https://deploy-preview-55--formacion.example.com',
      ]) {
        expect(
          googleOAuthRedirectTo(
            isWeb: true,
            baseUri: Uri.parse('$origin/login?code=test#/dashboard'),
          ),
          '$origin/',
        );
      }
    });

    test('Fuera de Web no construye un redirect HTTP', () {
      expect(
        googleOAuthRedirectTo(
          isWeb: false,
          baseUri: Uri.parse('file:///app/login'),
        ),
        isNull,
      );
    });
  });

  group('Sesión y protección de rutas', () {
    test('Sin sesión bloquea todas las rutas privadas', () {
      final auth = _controller(_client());

      expect(auth.enabled, isTrue);
      expect(auth.hasValidSession, isFalse);
      expect(auth.redirect('/'), '/login');
      expect(auth.redirect('/login'), isNull);
      for (final path in _privatePaths) {
        expect(auth.redirect(path), '/login', reason: path);
      }
    });

    test(
      'Una sesión persistida vigente evita pedir login nuevamente',
      () async {
        final client = _client();
        await client.auth.setInitialSession(jsonEncode(_sessionJson()));
        final auth = _controller(client);

        expect(auth.hasValidSession, isTrue);
        await _waitForAuthorization(auth);
        expect(auth.redirect('/'), '/dashboard');
        expect(auth.redirect('/login'), '/dashboard');
        for (final path in _privatePaths) {
          expect(auth.redirect(path), isNull, reason: path);
        }
      },
    );

    test('Una sesión persistida expirada no concede acceso', () async {
      final client = _client();
      await client.auth.setInitialSession(
        jsonEncode(_sessionJson(expired: true)),
      );
      final auth = _controller(client);

      expect(client.auth.currentSession, isNotNull);
      expect(auth.hasValidSession, isFalse);
      expect(auth.redirect('/dashboard'), '/login');
      expect(auth.redirect('/login'), isNull);
    });

    test('Fallback conserva las rutas sin inicializar Supabase', () async {
      final auth = _controller(null);

      expect(auth.enabled, isFalse);
      expect(auth.hasValidSession, isFalse);
      for (final path in ['/', '/login', ..._privatePaths]) {
        expect(auth.redirect(path), isNull, reason: path);
      }
      await auth.signInWithGoogle();
      await auth.signOut();
      expect(auth.error, isNull);
      expect(auth.isSigningIn, isFalse);
    });

    test(
      'SignedIn y SignedOut notifican y logout llama Supabase Auth',
      () async {
        final requests = <http.Request>[];
        final client = _client(requests: requests);
        final auth = _controller(client);
        var notifications = 0;
        auth.addListener(() => notifications++);

        await _signIn(client);
        await _waitForAuthorization(auth);
        expect(auth.hasValidSession, isTrue);
        expect(notifications, greaterThan(0));
        final signedInNotifications = notifications;

        await auth.signOut();
        await Future<void>.delayed(Duration.zero);
        expect(auth.hasValidSession, isFalse);
        expect(auth.redirect('/dashboard'), '/login');
        expect(notifications, greaterThan(signedInNotifications));
        final logout = requests.singleWhere(
          (request) => request.url.path == '/auth/v1/logout',
        );
        expect(logout.method, 'POST');
        expect(logout.headers['authorization'], startsWith('Bearer '));
      },
    );

    test(
      'Errores de Auth se reportan sin excepción de stream sin manejar',
      () async {
        final client = _client();
        final auth = _controller(client);
        var notifications = 0;
        auth.addListener(() => notifications++);

        await expectLater(
          client.auth.recoverSession('{}'),
          throwsA(isA<AuthException>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(auth.error, isNotEmpty);
        expect(auth.hasValidSession, isFalse);
        expect(notifications, greaterThan(0));

        await _signIn(client);
        await _waitForAuthorization(auth);
        expect(auth.error, isNull);
        expect(auth.hasValidSession, isTrue);
      },
    );
  });

  group('Botón Google OAuth', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'Lanza Google y espera la sesión del callback para autorizar',
      () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return true;
            });
        final auth = _controller(_client());
        final signingInStates = <bool>[];
        auth.addListener(() => signingInStates.add(auth.isSigningIn));

        await auth.signInWithGoogle();

        final launch = calls.singleWhere((call) => call.method == 'launch');
        final uri = Uri.parse((launch.arguments as Map)['url'] as String);
        expect(uri.path, '/auth/v1/authorize');
        expect(uri.queryParameters['provider'], 'google');
        expect(uri.queryParameters['code_challenge'], isNotEmpty);
        expect(auth.error, isNull);
        expect(signingInStates, [true, false]);
        expect(auth.hasValidSession, isFalse);
        expect(auth.redirect('/dashboard'), '/login');
      },
    );

    test('Un launch rechazado reporta error y no crea una sesión', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
      final auth = _controller(_client());

      await auth.signInWithGoogle();

      expect(auth.error, isNotEmpty);
      expect(auth.isSigningIn, isFalse);
      expect(auth.hasValidSession, isFalse);
    });

    test('Una falla del navegador se reporta y restablece el botón', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'launch_failed');
          });
      final auth = _controller(_client());

      await auth.signInWithGoogle();

      expect(auth.error, isNotEmpty);
      expect(auth.isSigningIn, isFalse);
      expect(auth.hasValidSession, isFalse);
    });

    test('Descarta doble click y cierre durante un launch pendiente', () async {
      final launchStarted = Completer<void>();
      final launchResult = Completer<bool>();
      var launches = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            launches++;
            launchStarted.complete();
            return launchResult.future;
          });
      final auth = AuthController(_client());
      var disposed = false;
      addTearDown(() {
        if (!disposed) auth.dispose();
      });
      final pendingSignIn = auth.signInWithGoogle();
      await launchStarted.future;
      await auth.signInWithGoogle();
      expect(launches, 1);
      expect(auth.isSigningIn, isTrue);

      auth.dispose();
      disposed = true;
      launchResult.complete(true);
      await pendingSignIn;

      expect(auth.isSigningIn, isFalse);
      expect(auth.hasValidSession, isFalse);
    });
  });

  test('El provider respeta USE_SUPABASE y conserva el fallback', () {
    final client = _client();
    final container = ProviderContainer(
      overrides: [
        if (SupabaseConfig.enabled)
          supabaseClientProvider.overrideWithValue(client)
        else
          supabaseClientProvider.overrideWith(
            (ref) => throw StateError('No debe leerse Supabase en fallback'),
          ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(authControllerProvider).enabled,
      SupabaseConfig.enabled,
    );
  });

  testWidgets('Router protege rutas y se refresca por login/logout', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = (await tester.runAsync(
      () async => _client(requests: requests, registerDisposal: false),
    ))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final auth = AuthController(client);
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith((ref) => auth)],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final router = container.read(appRouterProvider);

    late BuildContext routerContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            routerContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    Future<String> parse(String path) async {
      router.go(path);
      final match = await router.routeInformationParser
          .parseRouteInformationWithDependencies(
            router.routeInformationProvider.value,
            routerContext,
          );
      await router.routerDelegate.setNewRoutePath(match);
      return router.routerDelegate.currentConfiguration.uri.path;
    }

    expect(await parse('/'), '/login');
    expect(await parse('/empleados/10'), '/login');
    var refreshes = 0;
    router.routeInformationProvider.addListener(() => refreshes++);
    await tester.runAsync(() async {
      await _signIn(client);
      await auth.validateAuthorization();
    });
    await tester.pump();
    expect(refreshes, greaterThan(0));
    expect(await parse('/login'), '/dashboard');
    expect(await parse('/dashboard'), '/dashboard');
    expect(identical(container.read(appRouterProvider), router), isTrue);
    final signedInRefreshes = refreshes;
    await tester.runAsync(auth.signOut);
    await tester.pump();
    expect(refreshes, greaterThan(signedInRefreshes));
    expect(await parse('/dashboard'), '/login');
    expect(
      requests.any((request) => request.url.path == '/auth/v1/logout'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
