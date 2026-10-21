import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Apariencia elegida por el usuario: sistema, claro u oscuro. Se guarda en
/// el navegador y se lee antes de arrancar la app (ver `main.dart`) para que
/// no aparezca un instante con el tema equivocado.
final temaProvider = NotifierProvider<TemaController, ThemeMode>(
  TemaController.new,
);

class TemaController extends Notifier<ThemeMode> {
  static const clavePreferencia = 'apariencia';

  final ThemeMode _inicial;

  TemaController([this._inicial = ThemeMode.system]);

  @override
  ThemeMode build() => _inicial;

  Future<void> cambiar(ThemeMode modo) async {
    if (modo == state) return;
    state = modo;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(clavePreferencia, modo.name);
  }

  /// Preferencia guardada; sin preferencia (o con un valor desconocido),
  /// sigue al sistema operativo.
  static Future<ThemeMode> leerGuardado() async {
    final preferencias = await SharedPreferences.getInstance();
    final guardado = preferencias.getString(clavePreferencia);
    return ThemeMode.values.asNameMap()[guardado] ?? ThemeMode.system;
  }
}
