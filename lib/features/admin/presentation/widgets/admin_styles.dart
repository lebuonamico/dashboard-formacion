import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:flutter/material.dart';

/// Status chip colors of an authorized user, with the app's traffic light:
/// active green, blocked amber, deleted red.
ColorPair userStatusColors(AppColors colors, UserStatus status) =>
    switch (status) {
      UserStatus.active => colors.success,
      UserStatus.blocked => colors.warning,
      UserStatus.deleted => colors.danger,
    };

/// Admin panel field decoration. Borders, fill and colors come from
/// AppTheme's `inputDecorationTheme`.
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
