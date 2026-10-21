import 'dart:io';

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/tema_provider.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Relación de contraste WCAG entre dos colores opacos.
double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Los fondos de chip del modo oscuro son translúcidos: se mide el color que
/// realmente se ve sobre la superficie.
Color _sobre(Color fondo, Color superficie) =>
    Color.alphaBlend(fondo, superficie);

void main() {
  group('Preferencia de apariencia', () {
    test('sin preferencia guardada sigue al sistema', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await TemaController.leerGuardado(), ThemeMode.system);
    });

    test('un valor desconocido también sigue al sistema', () async {
      SharedPreferences.setMockInitialValues({
        TemaController.clavePreferencia: 'violeta',
      });
      expect(await TemaController.leerGuardado(), ThemeMode.system);
    });

    test('cambiar el modo lo aplica y lo guarda', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(temaProvider.notifier).cambiar(ThemeMode.dark);

      expect(container.read(temaProvider), ThemeMode.dark);
      expect(await TemaController.leerGuardado(), ThemeMode.dark);
    });

    test('arranca con el modo leído antes de runApp', () {
      final container = ProviderContainer(
        overrides: [
          temaProvider.overrideWith(() => TemaController(ThemeMode.light)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(temaProvider), ThemeMode.light);
    });
  });

  group('Temas', () {
    for (final (nombre, tema) in [
      ('claro', AppTheme.light()),
      ('oscuro', AppTheme.dark()),
    ]) {
      test('el tema $nombre trae los colores propios de la app', () {
        expect(tema.extension<AppColors>(), isNotNull);
        expect(
          tema.scaffoldBackgroundColor,
          tema.colorScheme.surfaceContainerLow,
        );
      });

      test('los textos del tema $nombre cumplen contraste AA', () {
        final cs = tema.colorScheme;
        final c = tema.extension<AppColors>()!;
        final superficie = cs.surface;

        final pares = <String, (Color, Color)>{
          'texto principal': (cs.onSurface, superficie),
          'texto secundario': (cs.onSurfaceVariant, superficie),
          'texto intermedio': (c.textoIntermedio, superficie),
          'marca sobre superficie': (cs.primary, superficie),
          'texto sobre la página': (cs.onSurface, cs.surfaceContainerLow),
          'error': (cs.error, superficie),
          for (final (etiqueta, par) in [
            ('éxito', c.exito),
            ('advertencia', c.advertencia),
            ('peligro', c.peligro),
            ('negocio', c.negocio),
            ('blandas', c.blandas),
            ('exploración', c.exploracion),
            ('dictado', c.dictado),
            ('trainee', c.trainee),
            ('junior', c.junior),
            ('semisenior', c.semisenior),
            ('senior', c.senior),
            ('manager', c.manager),
          ])
            'chip $etiqueta': (par.texto, _sobre(par.fondo, superficie)),
        };

        final insuficientes = [
          for (final MapEntry(key: etiqueta, value: (texto, fondo))
              in pares.entries)
            if (_contraste(texto, fondo) < 4.5)
              '$etiqueta: ${_contraste(texto, fondo).toStringAsFixed(2)}',
        ];
        expect(insuficientes, isEmpty, reason: 'tema $nombre');
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
      final decoracion = panel.decoration! as BoxDecoration;
      expect(decoracion.color, AppTheme.dark().colorScheme.surface);
      expect(
        tester.widget<Text>(find.text('Sin datos')).style!.color,
        AppTheme.dark().colorScheme.onSurface,
      );
    });
  });

  test('no hay colores escritos fuera de lib/core/theme', () {
    final literal = RegExp(
      r'Color\(0x|Color\.from(ARGB|RGBO)\(|Colors\.(?!transparent\b)\w+',
    );
    final infracciones = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      final ruta = archivo.path.replaceAll(r'\', '/');
      if (archivo is! File ||
          !ruta.endsWith('.dart') ||
          ruta.startsWith('lib/core/theme/')) {
        continue;
      }
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (literal.hasMatch(lineas[i])) {
          infracciones.add('$ruta:${i + 1}: ${lineas[i].trim()}');
        }
      }
    }
    expect(
      infracciones,
      isEmpty,
      reason:
          'Los colores salen del tema (context.colorScheme / context.colores).',
    );
  });
}
