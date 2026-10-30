import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/core/theme/theme_mode_provider.dart';
import 'package:app_finnegans/features/auth/presentation/widgets/user_avatar.dart';
import 'package:app_finnegans/core/widgets/theme_transition.dart';
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
    themeMode: ref.watch(themeModeProvider),
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => ThemeTransition(child: child!),
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
        themeModeProvider.overrideWith(
          () => ThemeModeController(ThemeMode.light),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _App()),
    );
    BuildContext context() => tester.element(find.byType(UserAvatar));
    expect(Theme.of(context()).brightness, Brightness.light);

    await tester.tap(find.byType(UserAvatar));
    await tester.pumpAndSettle();
    // El switch refleja el tema actual (claro).
    final toggleSwitch = find.byKey(const Key('apariencia_switch'));
    expect(find.text('Tema oscuro'), findsOneWidget);
    expect(tester.widget<Switch>(toggleSwitch).value, isFalse);

    await tester.tap(toggleSwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // A mitad del fundido: el tema nuevo ya está aplicado y la captura del
    // anterior se desvanece encima.
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(Theme.of(context()).brightness, Brightness.dark);
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
    expect(await ThemeModeController.readSaved(), ThemeMode.dark);

    // El menú sigue abierto y el switch quedó encendido; apagarlo vuelve al
    // tema claro.
    expect(tester.widget<Switch>(toggleSwitch).value, isTrue);
    await tester.tap(toggleSwitch);
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(await ThemeModeController.readSaved(), ThemeMode.light);
    expect(tester.takeException(), isNull);
  });

  group('Lidera y Pertenece a', () {
    final structure = OrgStructure(
      areas: [Area(id: '1', name: 'PRODUCTOS TECNOLÓGICOS')],
      teams: [
        Team(
          id: '10',
          areaId: '1',
          name: 'PLATAFORMA CORE',
          leaders: {'lider@finnegans.com'},
        ),
      ],
    );
    final own = Employee(
      employeeId: '5',
      firstName: 'Lía',
      lastName: 'Líder',
      seniority: Seniority.senior1,
      area: 'SERVICIOS',
      email: 'lider@finnegans.com',
      team: 'IMPLEMENTACIONES',
    );

    Future<void> openMenu(
      WidgetTester tester, {
      required String role,
      Employee? employee,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => _AuthWithRole('lider@finnegans.com', role),
          ),
          themeModeProvider.overrideWith(
            () => ThemeModeController(ThemeMode.light),
          ),
          orgStructureProvider.overrideWith((ref) async => structure),
          sessionEmployeeProvider.overrideWith((ref) async => employee),
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

    String text(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('Un líder ve lo que lidera y a qué pertenece', (tester) async {
      await openMenu(tester, role: 'teamLead', employee: own);

      expect(text(tester, 'cuenta_lidera'), 'PLATAFORMA CORE');
      expect(text(tester, 'cuenta_pertenece'), 'IMPLEMENTACIONES · SERVICIOS');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Un líder que no figura en la nómina lo dice', (tester) async {
      await openMenu(tester, role: 'teamLead');

      expect(text(tester, 'cuenta_pertenece'), OrgStructure.notInPayroll);
    });

    testWidgets('Un administrador no ve esos datos', (tester) async {
      await openMenu(tester, role: 'admin', employee: own);

      expect(find.byKey(const Key('cuenta_lidera')), findsNothing);
      expect(find.byKey(const Key('cuenta_pertenece')), findsNothing);
    });
  });
}

/// Sesión con Supabase habilitado, un email y un rol fijos, sin cliente real.
class _AuthWithRole extends AuthController {
  final String _email;

  _AuthWithRole(this._email, String role) : super(null) {
    this.role = role;
  }

  @override
  bool get enabled => true;

  @override
  String? get email => _email;
}
