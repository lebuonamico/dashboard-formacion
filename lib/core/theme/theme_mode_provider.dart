import 'package:app_finnegans/core/theme/theme_preference_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themePreferenceRepositoryProvider = Provider<ThemePreferenceRepository>(
  (ref) => SharedPreferencesThemePreferenceRepository(),
);

/// Starts with the mode read before `runApp` (see `main.dart`), so the app
/// never shows a frame with the wrong theme.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  final ThemeMode _initial;

  ThemeModeNotifier([this._initial = ThemeMode.system]);

  @override
  ThemeMode build() => _initial;

  Future<void> change(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(themePreferenceRepositoryProvider).save(mode);
  }
}
