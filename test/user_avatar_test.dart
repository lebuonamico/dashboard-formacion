import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/providers/tema_provider.dart';
import 'package:app_finnegans/presentation/widgets/shared/user_avatar.dart';
import 'package:app_finnegans/presentation/widgets/transicion_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App mínima conectada al provider de apariencia, como `MyApp`.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(temaProvider),
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => TransicionTema(child: child!),
    home: const Scaffold(body: Align(child: UserAvatar())),
  );
}

void main() {
  testWidgets('El menú de la cuenta cambia y recuerda la apariencia', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => AuthController(null)),
        temaProvider.overrideWith(() => TemaController(ThemeMode.light)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _App()),
    );
    BuildContext contexto() => tester.element(find.byType(UserAvatar));
    expect(Theme.of(contexto()).brightness, Brightness.light);

    await tester.tap(find.byType(UserAvatar));
    await tester.pumpAndSettle();
    // Las tres opciones están en el menú, con la actual marcada.
    expect(find.text('Usar tema del sistema'), findsOneWidget);
    expect(find.text('Tema claro'), findsOneWidget);
    expect(find.text('Tema oscuro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('apariencia_dark')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // A mitad del fundido: el tema nuevo ya está aplicado y la captura del
    // anterior se desvanece encima.
    expect(container.read(temaProvider), ThemeMode.dark);
    expect(Theme.of(contexto()).brightness, Brightness.dark);
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
    expect(await TemaController.leerGuardado(), ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });

  group('Lidera y Pertenece a', () {
    final estructura = EstructuraOrganizacional(
      areas: [Area(id: '1', nombre: 'PRODUCTOS TECNOLÓGICOS')],
      equipos: [
        Equipo(
          id: '10',
          areaId: '1',
          nombre: 'PLATAFORMA CORE',
          lideres: {'lider@finnegans.com'},
        ),
      ],
    );
    final propio = Empleado(
      legajo: '5',
      nombre: 'Lía',
      apellido: 'Líder',
      seniority: Seniority.senior1,
      area: 'SERVICIOS',
      mail: 'lider@finnegans.com',
      equipo: 'IMPLEMENTACIONES',
    );

    Future<void> abrirMenu(
      WidgetTester tester, {
      required String rol,
      Empleado? empleado,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => _AuthConRol('lider@finnegans.com', rol),
          ),
          temaProvider.overrideWith(() => TemaController(ThemeMode.light)),
          estructuraProvider.overrideWith((ref) async => estructura),
          empleadoDeSesionProvider.overrideWith((ref) async => empleado),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const _App()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();
    }

    String texto(WidgetTester tester, String clave) =>
        tester.widget<Text>(find.byKey(Key(clave))).data!;

    testWidgets('Un líder ve lo que lidera y a qué pertenece', (tester) async {
      await abrirMenu(tester, rol: 'lider', empleado: propio);

      expect(texto(tester, 'cuenta_lidera'), 'PLATAFORMA CORE');
      expect(texto(tester, 'cuenta_pertenece'), 'IMPLEMENTACIONES · SERVICIOS');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Un líder que no figura en la nómina lo dice', (tester) async {
      await abrirMenu(tester, rol: 'lider');

      expect(
        texto(tester, 'cuenta_pertenece'),
        EstructuraOrganizacional.noFiguraEnNomina,
      );
    });

    testWidgets('Un administrador no ve esos datos', (tester) async {
      await abrirMenu(tester, rol: 'admin', empleado: propio);

      expect(find.byKey(const Key('cuenta_lidera')), findsNothing);
      expect(find.byKey(const Key('cuenta_pertenece')), findsNothing);
    });
  });
}

/// Sesión con Supabase habilitado, un email y un rol fijos, sin cliente real.
class _AuthConRol extends AuthController {
  final String _email;

  _AuthConRol(this._email, String rol) : super(null) {
    this.rol = rol;
  }

  @override
  bool get enabled => true;

  @override
  String? get email => _email;
}
