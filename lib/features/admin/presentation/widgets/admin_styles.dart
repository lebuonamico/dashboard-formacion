import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:flutter/material.dart';

/// Colores del chip de estado de un usuario autorizado, con el semáforo de
/// la app: activo en verde, bloqueado en ámbar y eliminado en rojo.
ColorPair userStatusColors(AppColors colors, UserStatus status) =>
    switch (status) {
      UserStatus.active => colors.success,
      UserStatus.blocked => colors.warning,
      UserStatus.deleted => colors.danger,
    };

/// Decoración de los campos del panel de administración. Bordes, relleno y
/// colores salen del `inputDecorationTheme` de `AppTheme`.
InputDecoration adminInputDecoration(
  String hint,
  IconData icon, {
  String? label,
  String? error,
}) => InputDecoration(
  labelText: label,
  errorText: error,
  hintText: hint,
  prefixIcon: Icon(icon, size: 19),
);

String formatStamp(DateTime? date) {
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}
