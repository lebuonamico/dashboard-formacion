import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:flutter/material.dart';

/// Colores del chip de estado de un usuario autorizado, con el semáforo de
/// la app: activo en verde, bloqueado en ámbar y eliminado en rojo.
ParColores coloresEstadoUsuario(AppColors colores, EstadoUsuario estado) =>
    switch (estado) {
      EstadoUsuario.activo => colores.exito,
      EstadoUsuario.bloqueado => colores.advertencia,
      EstadoUsuario.eliminado => colores.peligro,
    };

/// Decoración de los campos del panel de administración. Bordes, relleno y
/// colores salen del `inputDecorationTheme` de `AppTheme`.
InputDecoration adminInputDecoration(
  String hint,
  IconData icono, {
  String? label,
  String? error,
}) => InputDecoration(
  labelText: label,
  errorText: error,
  hintText: hint,
  prefixIcon: Icon(icono, size: 19),
);

String formatearSello(DateTime? fecha) {
  if (fecha == null) return '—';
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year} $hora:$minuto';
}
