import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemePreferenceRepository {
  Future<ThemeMode> read();

  Future<void> save(ThemeMode mode);
}

class SharedPreferencesThemePreferenceRepository
    implements ThemePreferenceRepository {
  static const preferenceKey = 'apariencia';

  final SharedPreferencesAsync _preferences;

  SharedPreferencesThemePreferenceRepository([
    SharedPreferencesAsync? preferences,
  ]) : _preferences = preferences ?? SharedPreferencesAsync();

  /// Without a saved preference, or with an unknown one, the app follows the
  /// operating system.
  @override
  Future<ThemeMode> read() async {
    final saved = await _preferences.getString(preferenceKey);
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
  }

  @override
  Future<void> save(ThemeMode mode) =>
      _preferences.setString(preferenceKey, mode.name);
}
