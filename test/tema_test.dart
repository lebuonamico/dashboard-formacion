import 'dart:io';

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/tema_provider.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Relación de contraste WCAG entre dos colores opacos.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (light, dark) = la > lb ? (la, lb) : (lb, la);
  return (light + 0.05) / (dark + 0.05);
}

/// Los fondos de chip del modo oscuro son translúcidos: se mide el color que
/// realmente se ve sobre la superficie.
Color _over(Color background, Color surface) =>
    Color.alphaBlend(background, surface);

void main() {
  group('Preferencia de apariencia', () {
    test('sin preferencia guardada sigue al sistema', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ThemeModeController.readSaved(), ThemeMode.system);
    });

    test('un valor desconocido también sigue al sistema', () async {
      SharedPreferences.setMockInitialValues({
        ThemeModeController.preferenceKey: 'violeta',
      });
      expect(await ThemeModeController.readSaved(), ThemeMode.system);
    });

    test('cambiar el modo lo aplica y lo guarda', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).change(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(await ThemeModeController.readSaved(), ThemeMode.dark);
    });

    test('arranca con el modo leído antes de runApp', () {
      final container = ProviderContainer(
        overrides: [
          themeModeProvider.overrideWith(
            () => ThemeModeController(ThemeMode.light),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('Temas', () {
    for (final (name, theme) in [
      ('claro', AppTheme.light()),
      ('oscuro', AppTheme.dark()),
    ]) {
      test('el tema $name trae los colores propios de la app', () {
        expect(theme.extension<AppColors>(), isNotNull);
        expect(
          theme.scaffoldBackgroundColor,
          theme.colorScheme.surfaceContainerLow,
        );
      });

      test('los textos del tema $name cumplen contraste AA', () {
        final cs = theme.colorScheme;
        final c = theme.extension<AppColors>()!;
        final surface = cs.surface;

        final pairs = <String, (Color, Color)>{
          'texto principal': (cs.onSurface, surface),
          'texto secundario': (cs.onSurfaceVariant, surface),
          'texto intermedio': (c.intermediateText, surface),
          'marca sobre superficie': (cs.primary, surface),
          'texto sobre la página': (cs.onSurface, cs.surfaceContainerLow),
          'error': (cs.error, surface),
          for (final (label, pair) in [
            ('éxito', c.success),
            ('advertencia', c.warning),
            ('peligro', c.danger),
            ('negocio', c.business),
            ('blandas', c.softSkills),
            ('exploración', c.exploration),
            ('dictado', c.teaching),
            ('trainee', c.trainee),
            ('junior', c.junior),
            ('semisenior', c.semisenior),
            ('senior', c.senior),
            ('manager', c.manager),
          ])
            'chip $label': (pair.text, _over(pair.background, surface)),
        };

        final insufficient = [
          for (final MapEntry(key: label, value: (text, background))
              in pairs.entries)
            if (_contrast(text, background) < 4.5)
              '$label: ${_contrast(text, background).toStringAsFixed(2)}',
        ];
        expect(insufficient, isEmpty, reason: 'tema $name');
      });
    }

    testWidgets('en modo oscuro los paneles usan la superficie oscura', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: EmptyDataState(title: 'Sin datos')),
        ),
      );

      final panel = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Sin datos'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = panel.decoration! as BoxDecoration;
      expect(decoration.color, AppTheme.dark().colorScheme.surface);
      expect(
        tester.widget<Text>(find.text('Sin datos')).style!.color,
        AppTheme.dark().colorScheme.onSurface,
      );
    });
  });

  test('no hay colores escritos fuera de lib/core/theme', () {
    final literal = RegExp(
      r'\bColor\(0x|\bColor\.from(ARGB|RGBO)\(|\bColors\.(?!transparent\b)\w+',
    );
    final violations = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      final route = file.path.replaceAll(r'\', '/');
      if (file is! File ||
          !route.endsWith('.dart') ||
          route.startsWith('lib/core/theme/')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (literal.hasMatch(lines[i])) {
          violations.add('$route:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Los colores salen del tema (context.colorScheme / context.colores).',
    );
  });
}
