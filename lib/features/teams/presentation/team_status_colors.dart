import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:flutter/widgets.dart';

extension TeamStatusColors on TeamStatus {
  ColorPair colors(BuildContext context) {
    final colors = context.colors;
    return switch (this) {
      TeamStatus.onTarget => colors.success,
      TeamStatus.atRisk => colors.warning,
      TeamStatus.critical => colors.danger,
    };
  }
}
