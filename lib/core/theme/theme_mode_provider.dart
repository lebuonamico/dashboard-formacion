import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Apariencia elegida por el usuario: sistema, claro u oscuro. Se guarda en
/// el navegador y se lee antes de arrancar la app (ver `main.dart`) para que
/// no aparezca un instante con el tema equivocado.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const preferenceKey = 'apariencia';

  final ThemeMode _initial;

  ThemeModeController([this._initial = ThemeMode.system]);

  @override
  ThemeMode build() => _initial;

  Future<void> change(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, mode.name);
  }

  /// Preferencia guardada; sin preferencia (o con un valor desconocido),
  /// sigue al sistema operativo.
  static Future<ThemeMode> readSaved() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(preferenceKey);
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
  }
}
