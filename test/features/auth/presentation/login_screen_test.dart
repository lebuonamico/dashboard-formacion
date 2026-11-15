import 'package:app_finnegans/features/auth/presentation/login_screen.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/auth/presentation/providers/embedded_browser_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

Future<void> _showLogin(
  WidgetTester tester, {
  Size size = compactSize,
  bool supabase = true,
  bool embedded = false,
}) async {
  await pumpScreen(
    tester,
    initialLocation: '/login',
    size: size,
    overrides: [
      authProvider.overrideWith(
        () => AuthNotifier(
          supabase ? const AuthState() : const AuthState.disabled(),
        ),
      ),
      embeddedBrowserProvider.overrideWithValue(embedded),
    ],
    routes: [GoRoute(path: '/login', builder: (_, _) => const LoginScreen())],
  );
}

final _notice = find.byKey(const Key('login_navegador_embebido'));

void main() {
  for (final size in const [Size(360, 640), compactSize]) {
    testWidgets('A ${size.width.toInt()} px entra sin desbordes', (
      tester,
    ) async {
      await _showLogin(tester, size: size, embedded: true);

      expect(find.text('Iniciar sesión con Google'), findsOneWidget);
      expect(find.text('Términos de servicio'), findsOneWidget);
      expect(
        tester.getRect(find.text('Términos de servicio')).right,
        lessThanOrEqualTo(size.width),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Con texto grande (≈1.3) a 360 px tampoco desborda', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      initialLocation: '/login',
      size: const Size(360, 640),
      textScale: 0.65,
      overrides: [
        authProvider.overrideWith(() => AuthNotifier(const AuthState())),
        embeddedBrowserProvider.overrideWithValue(true),
      ],
      routes: [GoRoute(path: '/login', builder: (_, _) => const LoginScreen())],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('En el navegador de una app avisa y copia el enlace', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _showLogin(tester, embedded: true);

    expect(_notice, findsOneWidget);
    expect(find.textContaining('Abrí el portal en Chrome o Safari'), findsOne);
    // El botón de Google sigue, por si la detección se equivoca.
    final google = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Iniciar sesión con Google'),
    );
    expect(google.onPressed, isNotNull);
    final copy = find.byKey(const Key('login_copiar_enlace'));
    expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));

    await tester.tap(copy);
    await tester.pumpAndSettle();

    expect(copied, [portalLink()]);
    expect(copied.single, isNot(contains('#')));
    expect(find.text('Enlace copiado. Pegalo en Chrome o Safari.'), findsOne);
  });

  testWidgets('En un navegador común no avisa', (tester) async {
    await _showLogin(tester);
    expect(_notice, findsNothing);
  });

  testWidgets('En modo local no avisa: no hay login con Google', (
    tester,
  ) async {
    await _showLogin(tester, supabase: false, embedded: true);
    expect(_notice, findsNothing);
  });

  testWidgets('En escritorio el pie va en una sola línea', (tester) async {
    await _showLogin(tester, size: desktopSize);
    final support = tester.getCenter(find.text('Soporte')).dy;
    expect(tester.getCenter(find.text('Términos de servicio')).dy, support);
    expect(tester.takeException(), isNull);
  });
}
